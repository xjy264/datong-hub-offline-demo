package cn.datong.map.layout;

import cn.datong.map.security.CurrentUser;
import cn.datong.map.station.StationDtos.WorkshopView;
import cn.datong.map.station.WorkshopService;
import cn.datong.map.storage.ImageStorage;
import cn.datong.map.storage.StoredObject;
import cn.datong.map.storage.UploadPolicy;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MapDocumentServiceTest {
    private JdbcTemplate jdbc;
    private MapDocumentService service;

    @BeforeEach
    void setUp() {
        JdbcDataSource dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:" + System.nanoTime() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE map_workshop (id BIGINT AUTO_INCREMENT PRIMARY KEY, code VARCHAR(64) NOT NULL UNIQUE, name VARCHAR(128) NOT NULL, color VARCHAR(32) NOT NULL, sort_order INT NOT NULL DEFAULT 0)");
        jdbc.execute("CREATE TABLE map_station (id VARCHAR(64) PRIMARY KEY, name VARCHAR(128), auto_name VARCHAR(128), type VARCHAR(32), color VARCHAR(16), line_name VARCHAR(128), mileage VARCHAR(64), position_x DECIMAL(10,2), position_y DECIMAL(10,2), size DECIMAL(6,2), default_workshop_id VARCHAR(64))");
        jdbc.execute("CREATE TABLE station_profile (station_id VARCHAR(64) PRIMARY KEY, name VARCHAR(128), notes TEXT, workshop_id VARCHAR(64))");
        jdbc.execute("CREATE TABLE station_folder (id VARCHAR(80) PRIMARY KEY, station_id VARCHAR(64), parent_id VARCHAR(80), name VARCHAR(128), sort_order INT, created_at DATETIME)");
        jdbc.execute("CREATE TABLE station_image (id VARCHAR(80) PRIMARY KEY, station_id VARCHAR(64), folder_id VARCHAR(80), name VARCHAR(160), content_type VARCHAR(100), size_bytes BIGINT, bucket VARCHAR(128), object_name VARCHAR(512), created_at DATETIME)");
        jdbc.execute("CREATE TABLE map_document (id VARCHAR(80) PRIMARY KEY, name VARCHAR(128), pdf_bucket VARCHAR(128), pdf_object_name VARCHAR(512), background_bucket VARCHAR(128), background_object_name VARCHAR(512), background_url VARCHAR(512), width INT, height INT, created_by BIGINT, created_at DATETIME)");
        jdbc.execute("CREATE TABLE map_marker (id VARCHAR(80) PRIMARY KEY, map_id VARCHAR(80), station_id VARCHAR(64), position_x DECIMAL(10,2), position_y DECIMAL(10,2), size DECIMAL(6,2), created_at DATETIME, updated_at DATETIME)");
        jdbc.execute("CREATE TABLE map_interval (id VARCHAR(80) PRIMARY KEY, map_id VARCHAR(80), marker_a_id VARCHAR(80), marker_b_id VARCHAR(80), base_stations TEXT, created_at DATETIME, updated_at DATETIME)");
        jdbc.update("INSERT INTO map_workshop (id, code, name, color, sort_order) VALUES (1, 'north', '北部车间', '#0f766e', 10)");
        jdbc.update("INSERT INTO map_station VALUES ('xinzhou', '忻州站', '忻州站', '车站', 'red', '', '001', 10, 20, 4.4, 'north')");
        jdbc.update("INSERT INTO map_document VALUES ('default-map', '默认地图', NULL, NULL, NULL, NULL, '/assets/full-map.svg', 1191, 842, 1, CURRENT_TIMESTAMP)");
        service = new MapDocumentService(jdbc, new FakeStorage(), new PdfFirstPageRenderer(), new WorkshopService(jdbc), new UploadPolicy());
    }

    @Test
    void allowsMultipleMarkersForOneStation() {
        service.createMarker(new CurrentUser(1L), "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));
        service.createMarker(new CurrentUser(1L), "default-map", new MapDtos.MarkerRequest("xinzhou", 30, 40, 7));

        MapDtos.MapDetail detail = service.detail("default-map");

        assertThat(detail.markers()).hasSize(2);
        assertThat(detail.markers()).extracting(marker -> marker.station().id()).containsExactly("xinzhou", "xinzhou");
        assertThat(detail.markers()).extracting(marker -> marker.station().workshopId()).containsExactly(1L, 1L);
        assertThat(detail.workshops()).extracting(WorkshopView::id, WorkshopView::code, WorkshopView::name)
                .containsExactly(org.assertj.core.groups.Tuple.tuple(1L, "north", "北部车间"));
    }

    @Test
    void markerUsesLatestSharedStationProfile() {
        service.createMarker(new CurrentUser(1L), "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));
        service.createMarker(new CurrentUser(1L), "default-map", new MapDtos.MarkerRequest("xinzhou", 30, 40, 7));
        jdbc.update("INSERT INTO station_profile (station_id, name, notes, workshop_id) VALUES ('xinzhou', '新忻州站', '', 'north')");

        MapDtos.MapDetail detail = service.detail("default-map");

        assertThat(detail.markers()).extracting(marker -> marker.station().name()).containsExactly("新忻州站", "新忻州站");
    }

    @Test
    void deletingMarkerDoesNotDeleteStation() {
        MapDtos.MarkerView marker = service.createMarker(new CurrentUser(1L), "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));

        service.deleteMarker(new CurrentUser(1L), "default-map", marker.id());

        assertThat(service.detail("default-map").markers()).isEmpty();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM map_station WHERE id = 'xinzhou'", Integer.class)).isEqualTo(1);
    }

    @Test
    void authenticatedUserCanRenameMap() {
        MapDtos.MapSummary renamed = service.renameMap(new CurrentUser(1L), "default-map", new MapDtos.MapNameRequest("  新地图名  "));

        assertThat(renamed.name()).isEqualTo("新地图名");
        assertThat(service.detail("default-map").name()).isEqualTo("新地图名");
    }

    @Test
    void deleteMapRemovesMarkersAndUploadedObjects() {
        FakeStorage storage = new FakeStorage();
        service = new MapDocumentService(jdbc, storage, new PdfFirstPageRenderer(), new WorkshopService(jdbc), new UploadPolicy());
        jdbc.update("INSERT INTO map_document VALUES ('uploaded-map', '上传地图', 'test', 'maps/uploaded/source.pdf', 'test', 'maps/uploaded/background.png', '/api/maps/uploaded-map/background', 100, 100, 1, CURRENT_TIMESTAMP)");
        jdbc.update("INSERT INTO map_marker VALUES ('marker-1', 'uploaded-map', 'xinzhou', 10, 20, 8, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");

        service.deleteMap(new CurrentUser(1L), "uploaded-map");

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM map_document WHERE id = 'uploaded-map'", Integer.class)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM map_marker WHERE map_id = 'uploaded-map'", Integer.class)).isZero();
        assertThat(storage.removed).containsExactly("test/maps/uploaded/source.pdf", "test/maps/uploaded/background.png");
    }

    @Test
    void cannotDeleteLastMap() {
        assertThatThrownBy(() -> service.deleteMap(new CurrentUser(1L), "default-map"))
                .isInstanceOf(cn.datong.map.common.BusinessException.class)
                .hasMessage("至少保留一张地图");
    }

    @Test
    void createMapRemovesFirstObjectWhenSecondUploadFails() throws Exception {
        FakeStorage storage = new FakeStorage();
        storage.failOnUpload = 2;
        service = new MapDocumentService(jdbc, storage, new PdfFirstPageRenderer(), new WorkshopService(jdbc), new UploadPolicy());

        assertThatThrownBy(() -> service.createMap(new CurrentUser(1L), "地图", new MockMultipartFile(
                "file", "map.pdf", "application/pdf", onePagePdf())))
                .isInstanceOf(RuntimeException.class);

        assertThat(storage.removed).anyMatch(value -> value.endsWith("/source.pdf"));
    }

    @Test
    void authenticatedUserCanMutateLayout() {
        CurrentUser user = new CurrentUser(2L);
        jdbc.update("INSERT INTO map_document VALUES ('uploaded-map', '上传地图', NULL, NULL, NULL, NULL, '/api/maps/uploaded-map/background', 100, 100, 1, CURRENT_TIMESTAMP)");

        MapDtos.MarkerView marker = service.createMarker(user, "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));
        MapDtos.MapSummary renamed = service.renameMap(user, "default-map", new MapDtos.MapNameRequest("全员可编辑"));
        service.deleteMap(user, "uploaded-map");

        assertThat(marker.station().id()).isEqualTo("xinzhou");
        assertThat(renamed.name()).isEqualTo("全员可编辑");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM map_document WHERE id = 'uploaded-map'", Integer.class)).isZero();
    }

    @Test
    void createsUpdatesAndDeletesStationInterval() {
        jdbc.update("INSERT INTO map_station VALUES ('meijiazhuang', '梅家庄', '梅家庄', '车站', 'red', '', '', 110, 20, 4.4, 'north')");
        jdbc.update("INSERT INTO map_marker VALUES ('marker-a', 'default-map', 'xinzhou', 10, 20, 4.4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");
        jdbc.update("INSERT INTO map_marker VALUES ('marker-b', 'default-map', 'meijiazhuang', 110, 20, 4.4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");

        MapDtos.IntervalView created = service.createInterval(new CurrentUser(2L), "default-map",
                new MapDtos.IntervalRequest("marker-a", "marker-b", List.of("茶坞K220+550基站", "茶坞东K221+550基站")));

        assertThat(created.markerAId()).isEqualTo("marker-a");
        assertThat(created.markerBId()).isEqualTo("marker-b");
        assertThat(created.baseStations()).containsExactly("茶坞K220+550基站", "茶坞东K221+550基站");
        assertThat(service.detail("default-map").intervals()).containsExactly(created);

        MapDtos.IntervalView updated = service.updateInterval(new CurrentUser(2L), "default-map", created.id(),
                new MapDtos.IntervalRequest("marker-a", "marker-b", List.of("茶坞西K550+551基站")));
        assertThat(updated.baseStations()).containsExactly("茶坞西K550+551基站");

        service.deleteInterval(new CurrentUser(2L), "default-map", created.id());
        assertThat(service.detail("default-map").intervals()).isEmpty();
    }

    @Test
    void rejectsIntervalWithSameStationButtonAtBothEnds() {
        jdbc.update("INSERT INTO map_marker VALUES ('marker-a', 'default-map', 'xinzhou', 10, 20, 4.4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");

        assertThatThrownBy(() -> service.createInterval(new CurrentUser(2L), "default-map",
                new MapDtos.IntervalRequest("marker-a", "marker-a", List.of("基站"))))
                .isInstanceOf(cn.datong.map.common.BusinessException.class)
                .hasMessage("请选择两个不同的车站按钮");
    }

    private static class FakeStorage implements ImageStorage {
        private final java.util.List<String> removed = new java.util.ArrayList<>();
        private int uploadCount;
        private int failOnUpload;

        @Override
        public StoredObject upload(InputStream input, long size, String contentType, String objectName) {
            uploadCount++;
            if (uploadCount == failOnUpload) throw new RuntimeException("storage failed");
            return new StoredObject("test", objectName, size, contentType);
        }

        @Override
        public InputStream open(String bucket, String objectName) {
            return new ByteArrayInputStream(new byte[]{1, 2, 3});
        }

        @Override
        public void remove(String bucket, String objectName) {
            removed.add(bucket + "/" + objectName);
        }
    }

    private byte[] onePagePdf() throws Exception {
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            document.addPage(new PDPage());
            document.save(output);
            return output.toByteArray();
        }
    }
}

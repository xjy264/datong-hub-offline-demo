package cn.datong.map.layout;

import cn.datong.map.security.CurrentUser;
import cn.datong.map.station.StationDtos.WorkshopView;
import cn.datong.map.station.WorkshopService;
import cn.datong.map.storage.ImageStorage;
import cn.datong.map.storage.StoredObject;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;

import java.io.ByteArrayInputStream;
import java.io.InputStream;

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
        jdbc.update("INSERT INTO map_workshop (id, code, name, color, sort_order) VALUES (1, 'north', '北部车间', '#0f766e', 10)");
        jdbc.update("INSERT INTO map_station VALUES ('xinzhou', '忻州站', '忻州站', '车站', 'red', '', '001', 10, 20, 4.4, 'north')");
        jdbc.update("INSERT INTO map_document VALUES ('default-map', '默认地图', NULL, NULL, NULL, NULL, '/assets/full-map.svg', 1191, 842, 1, CURRENT_TIMESTAMP)");
        service = new MapDocumentService(jdbc, new FakeStorage(), new PdfFirstPageRenderer(), new WorkshopService(jdbc));
    }

    @Test
    void allowsMultipleMarkersForOneStation() {
        service.createMarker(new CurrentUser(1L, true), "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));
        service.createMarker(new CurrentUser(1L, true), "default-map", new MapDtos.MarkerRequest("xinzhou", 30, 40, 7));

        MapDtos.MapDetail detail = service.detail("default-map");

        assertThat(detail.markers()).hasSize(2);
        assertThat(detail.markers()).extracting(marker -> marker.station().id()).containsExactly("xinzhou", "xinzhou");
        assertThat(detail.markers()).extracting(marker -> marker.station().workshopId()).containsExactly(1L, 1L);
        assertThat(detail.workshops()).extracting(WorkshopView::id, WorkshopView::code, WorkshopView::name)
                .containsExactly(org.assertj.core.groups.Tuple.tuple(1L, "north", "北部车间"));
    }

    @Test
    void markerUsesLatestSharedStationProfile() {
        service.createMarker(new CurrentUser(1L, true), "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));
        service.createMarker(new CurrentUser(1L, true), "default-map", new MapDtos.MarkerRequest("xinzhou", 30, 40, 7));
        jdbc.update("INSERT INTO station_profile (station_id, name, notes, workshop_id) VALUES ('xinzhou', '新忻州站', '', 'north')");

        MapDtos.MapDetail detail = service.detail("default-map");

        assertThat(detail.markers()).extracting(marker -> marker.station().name()).containsExactly("新忻州站", "新忻州站");
    }

    @Test
    void deletingMarkerDoesNotDeleteStation() {
        MapDtos.MarkerView marker = service.createMarker(new CurrentUser(1L, true), "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7));

        service.deleteMarker(new CurrentUser(1L, true), "default-map", marker.id());

        assertThat(service.detail("default-map").markers()).isEmpty();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM map_station WHERE id = 'xinzhou'", Integer.class)).isEqualTo(1);
    }

    @Test
    void nonAdminCannotMutateLayout() {
        CurrentUser user = new CurrentUser(2L, false);

        assertThatThrownBy(() -> service.createMarker(user, "default-map", new MapDtos.MarkerRequest("xinzhou", 10, 20, 7)))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessage("当前账号没有地图布局编辑权限");
    }

    private static class FakeStorage implements ImageStorage {
        @Override
        public StoredObject upload(byte[] bytes, String contentType, String objectName) {
            return new StoredObject("test", objectName, bytes.length, contentType);
        }

        @Override
        public InputStream open(String bucket, String objectName) {
            return new ByteArrayInputStream(new byte[]{1, 2, 3});
        }

        @Override
        public void remove(String bucket, String objectName) {
        }
    }
}

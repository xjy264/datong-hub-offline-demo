package cn.datong.map.station;

import cn.datong.map.common.BusinessException;
import cn.datong.map.station.StationDtos.CreateStationRequest;
import cn.datong.map.station.StationDtos.ProfileRequest;
import cn.datong.map.station.StationDtos.WorkshopView;
import cn.datong.map.storage.ImageStorage;
import cn.datong.map.storage.StoredObject;
import cn.datong.map.storage.UploadPolicy;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;

import java.io.ByteArrayInputStream;
import java.io.InputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.groups.Tuple.tuple;

class StationServiceWorkshopTest {
    private JdbcTemplate jdbc;
    private StationService stations;
    private WorkshopService workshops;
    private NoopImageStorage storage;

    @BeforeEach
    void setUp() {
        JdbcDataSource dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:" + System.nanoTime() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE map_workshop (id BIGINT AUTO_INCREMENT PRIMARY KEY, code VARCHAR(64) NOT NULL UNIQUE, name VARCHAR(128) NOT NULL, color VARCHAR(32) NOT NULL, sort_order INT NOT NULL DEFAULT 0)");
        jdbc.execute("CREATE TABLE map_station (id VARCHAR(64) PRIMARY KEY, name VARCHAR(128), auto_name VARCHAR(128), type VARCHAR(32), color VARCHAR(16), line_name VARCHAR(128), mileage VARCHAR(64), position_x DECIMAL(10,2), position_y DECIMAL(10,2), size DECIMAL(6,2), default_workshop_id VARCHAR(64))");
        jdbc.execute("CREATE TABLE station_profile (station_id VARCHAR(64) PRIMARY KEY, name VARCHAR(128), notes TEXT, workshop_id VARCHAR(64), updated_at DATETIME)");
        jdbc.execute("CREATE TABLE station_folder (id VARCHAR(80) PRIMARY KEY, station_id VARCHAR(64), parent_id VARCHAR(80), name VARCHAR(128), sort_order INT, created_at DATETIME, updated_at DATETIME)");
        jdbc.execute("CREATE TABLE station_image (id VARCHAR(80) PRIMARY KEY, station_id VARCHAR(64), folder_id VARCHAR(80), name VARCHAR(160), content_type VARCHAR(100), size_bytes BIGINT, bucket VARCHAR(128), object_name VARCHAR(512), created_at DATETIME)");
        jdbc.update("INSERT INTO map_workshop (id, code, name, color, sort_order) VALUES (1, 'north', '北部车间', '#0f766e', 10), (2, 'middle', '中部车间', '#1d4ed8', 20)");
        jdbc.update("INSERT INTO map_station VALUES ('station-1', '红进塔', '红进塔', '车站', 'red', '', '261.396', 1, 2, 4.4, 'north')");
        workshops = new WorkshopService(jdbc);
        storage = new NoopImageStorage();
        stations = new StationService(jdbc, storage, new ObjectMapper(), workshops, new UploadPolicy());
    }

    @Test
    void listsWorkshopsWithNumericIds() {
        assertThat(workshops.listWorkshops())
                .extracting(WorkshopView::id, WorkshopView::code, WorkshopView::name, WorkshopView::color)
                .containsExactly(tuple(1L, "north", "北部车间", "#0f766e"), tuple(2L, "middle", "中部车间", "#1d4ed8"));
    }

    @Test
    void stationViewsExposeNumericWorkshopIdFromLegacyCode() {
        assertThat(stations.listStations().getFirst().workshopId()).isEqualTo(1L);
    }

    @Test
    void updateProfileStoresLegacyCodeWhenRequestUsesNumericId() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 2L));

        assertThat(jdbc.queryForObject("SELECT workshop_id FROM station_profile WHERE station_id = 'station-1'", String.class)).isEqualTo("middle");
        assertThat(stations.listStations().getFirst().workshopId()).isEqualTo(2L);
    }

    @Test
    void updateProfileTrimsAndStoresMileage() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 1L, null, " K123+456 "));

        assertThat(stations.listStations().getFirst().mileage()).isEqualTo("K123+456");
    }

    @Test
    void updateProfileCanClearMileage() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 1L, null, "   "));

        assertThat(stations.listStations().getFirst().mileage()).isEmpty();
    }

    @Test
    void legacyProfileRequestKeepsMileage() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 1L));

        assertThat(stations.listStations().getFirst().mileage()).isEqualTo("261.396");
    }

    @Test
    void updateProfileRejectsMileageLongerThanDatabaseColumn() {
        assertThatThrownBy(() -> stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 1L, null, "K".repeat(65))))
                .isInstanceOf(BusinessException.class)
                .hasMessage("公里标不能超过64个字符");
    }

    @Test
    void updateProfileCanChangeStationColorWhenProvided() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 1L, "blue"));

        StationDtos.StationView blue = stations.listStations().getFirst();
        assertThat(blue.color()).isEqualTo("blue");
        assertThat(blue.type()).isEqualTo("已撤站");

        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 1L, "red"));

        StationDtos.StationView red = stations.listStations().getFirst();
        assertThat(red.color()).isEqualTo("red");
        assertThat(red.type()).isEqualTo("车站");
    }

    @Test
    void updateProfileWithoutColorKeepsStationColor() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 2L));

        StationDtos.StationView station = stations.listStations().getFirst();
        assertThat(station.color()).isEqualTo("red");
        assertThat(station.type()).isEqualTo("车站");
    }

    @Test
    void blankWorkshopKeepsStationDefaultWorkshop() {
        stations.updateProfile("station-1", new ProfileRequest("红进塔", "", null));

        assertThat(stations.listStations().getFirst().workshopId()).isEqualTo(1L);
    }

    @Test
    void rejectsUnknownWorkshopWhenUpdatingProfile() {
        assertThatThrownBy(() -> stations.updateProfile("station-1", new ProfileRequest("红进塔", "", 99L)))
                .isInstanceOf(BusinessException.class)
                .hasMessage("车间不存在");
    }

    @Test
    void createsStationFromUserEnteredNameAndSelectedWorkshop() {
        StationDtos.StationView created = stations.createStation(new CreateStationRequest("  新站  ", "blue", 2L, 12.5, 34.5, 4.4));

        assertThat(created.name()).isEqualTo("新站");
        assertThat(created.autoName()).isEqualTo("新站");
        assertThat(created.color()).isEqualTo("blue");
        assertThat(created.type()).isEqualTo("已撤站");
        assertThat(created.workshopId()).isEqualTo(2L);
        assertThat(created.position().x()).isEqualTo(12.5);
        assertThat(created.position().y()).isEqualTo(34.5);
    }

    @Test
    void returnsExistingStationByNameWithoutChangingWorkshop() {
        StationDtos.StationView existing = stations.createStation(new CreateStationRequest("  红进塔  ", "blue", 2L, 12.5, 34.5, 4.4));

        assertThat(existing.id()).isEqualTo("station-1");
        assertThat(existing.workshopId()).isEqualTo(1L);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM map_station", Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT default_workshop_id FROM map_station WHERE id = 'station-1'", String.class)).isEqualTo("north");
    }

    @Test
    void rejectsBlankStationNameWhenCreatingStation() {
        assertThatThrownBy(() -> stations.createStation(new CreateStationRequest("  ", "red", 1L, 1, 2, 4.4)))
                .isInstanceOf(BusinessException.class)
                .hasMessage("车站名称不能为空");
    }

    @Test
    void uploadsImagesToFolderThatHasChildren() throws Exception {
        StationDtos.FolderView root = stations.addFolder("station-1", new StationDtos.FolderRequest(null, "根目录"));
        stations.addFolder("station-1", new StationDtos.FolderRequest(root.id(), "子目录"));
        byte[] originalBytes = new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};

        var uploaded = stations.uploadImages("station-1", root.id(), new MockMultipartFile[]{
                new MockMultipartFile("files", "a.png", "image/png", originalBytes)
        });

        assertThat(uploaded).hasSize(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM station_image WHERE folder_id = ?", Integer.class, root.id())).isEqualTo(1);
        assertThat(storage.lastUploadBytes).isEqualTo(originalBytes);
    }

    @Test
    void uploadsAndListsStationOverviewImagesWithoutFolder() throws Exception {
        byte[] originalBytes = new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};

        var uploaded = stations.uploadOverviewImages("station-1", new MockMultipartFile[]{
                new MockMultipartFile("files", "overview.png", "image/png", originalBytes)
        });

        assertThat(uploaded).hasSize(1);
        assertThat(jdbc.queryForObject("SELECT folder_id FROM station_image WHERE id = ?", String.class, uploaded.getFirst().id())).isNull();
        assertThat(storage.lastObjectName).contains("stations/station-1/overview/");
        assertThat(stations.listStations().getFirst().overviewImages()).extracting(StationDtos.StationImageView::name)
                .containsExactly("overview.png");
        assertThat(stations.listStations().getFirst().folders()).isEmpty();
    }

    @Test
    void deletesOverviewImageMetadataAndStoredObject() throws Exception {
        var uploaded = stations.uploadOverviewImages("station-1", new MockMultipartFile[]{
                new MockMultipartFile("files", "overview.png", "image/png", new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a})
        });

        stations.deleteImage(uploaded.getFirst().id());

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM station_image", Integer.class)).isZero();
        assertThat(storage.removed).containsExactly("test/" + storage.lastObjectName);
    }

    @Test
    void removesUploadedObjectWhenMetadataInsertFails() {
        StationDtos.FolderView root = stations.addFolder("station-1", new StationDtos.FolderRequest(null, "根目录"));
        jdbc.execute("DROP TABLE station_image");

        assertThatThrownBy(() -> stations.uploadImages("station-1", root.id(), new MockMultipartFile[]{
                new MockMultipartFile("files", "a.png", "image/png", new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a})
        })).isInstanceOf(Exception.class);

        assertThat(storage.removed).hasSize(1);
    }

    @Test
    void legacyImportRegeneratesFolderIdsInsteadOfOverwritingExistingFolders() throws Exception {
        jdbc.update("INSERT INTO station_folder VALUES ('legacy-folder', 'station-1', NULL, '原目录', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");
        String json = """
                {"userStations":{"station-1":{"name":"红进塔","workshop":"north","folders":[{"id":"legacy-folder","name":"导入目录","images":[],"children":[]}]}}}
                """;

        stations.importLegacy(new MockMultipartFile("file", "legacy.json", "application/json", json.getBytes()));

        assertThat(jdbc.queryForObject("SELECT name FROM station_folder WHERE id = 'legacy-folder'", String.class)).isEqualTo("原目录");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM station_folder", Integer.class)).isEqualTo(2);
    }

    @Test
    void legacyImportRejectsFoldersDeeperThanThreeLevels() {
        String json = """
                {"userStations":{"station-1":{"name":"红进塔","workshop":"north","folders":[{"name":"1","children":[{"name":"2","children":[{"name":"3","children":[{"name":"4"}]}]}]}]}}}
                """;

        assertThatThrownBy(() -> stations.importLegacy(new MockMultipartFile("file", "legacy.json", "application/json", json.getBytes())))
                .isInstanceOf(BusinessException.class)
                .hasMessage("导入目录最多支持三级");
    }

    @Test
    void legacyImportRemovesUploadedObjectsWhenLaterFolderFails() {
        String json = """
                {"userStations":{"station-1":{"name":"红进塔","workshop":"north","folders":[{"name":"1","images":[{"name":"a.png","dataUrl":"data:image/png;base64,iVBORw0KGgo="}],"children":[{"name":"2","children":[{"name":"3","children":[{"name":"4"}]}]}]}]}}}
                """;

        assertThatThrownBy(() -> stations.importLegacy(new MockMultipartFile("file", "legacy.json", "application/json", json.getBytes())))
                .hasMessage("导入目录最多支持三级");
        assertThat(storage.removed).hasSize(1);
    }


    @Test
    void createsWorkshopWithGeneratedCodeColorAndNextSortOrder() {
        WorkshopView created = workshops.createWorkshop("  新增车间  ");

        assertThat(created.id()).isGreaterThan(2L);
        assertThat(created.code()).startsWith("workshop-");
        assertThat(created.name()).isEqualTo("新增车间");
        assertThat(created.color()).isEqualTo("#0f766e");
        assertThat(created.sortOrder()).isEqualTo(30);
        assertThat(workshops.storageCode(created.id())).isEqualTo(created.code());
    }

    @Test
    void renamesWorkshop() {
        workshops.renameWorkshop(1L, "北部检修车间");

        assertThat(workshops.listWorkshops().getFirst().name()).isEqualTo("北部检修车间");
    }

    @Test
    void deletesWorkshopWithoutStations() {
        WorkshopView created = workshops.createWorkshop("临时车间");

        workshops.deleteWorkshop(created.id());

        assertThat(workshops.listWorkshops()).extracting(WorkshopView::id).doesNotContain(created.id());
    }

    @Test
    void deletesWorkshopWithStationsAndStationBecomesUngrouped() {
        workshops.deleteWorkshop(1L);

        assertThat(workshops.listWorkshops()).extracting(WorkshopView::id).doesNotContain(1L);
        assertThat(stations.listStations().getFirst().workshopId()).isNull();
    }

    @Test
    void rejectsBlankWorkshopName() {
        assertThatThrownBy(() -> workshops.renameWorkshop(1L, "  "))
                .isInstanceOf(BusinessException.class)
                .hasMessage("车间名称不能为空");
    }

    private static class NoopImageStorage implements ImageStorage {
        private byte[] lastUploadBytes;
        private String lastObjectName;
        private final java.util.List<String> removed = new java.util.ArrayList<>();

        @Override
        public StoredObject upload(InputStream input, long size, String contentType, String objectName) {
            lastObjectName = objectName;
            try {
                lastUploadBytes = input.readAllBytes();
            } catch (java.io.IOException ex) {
                throw new RuntimeException(ex);
            }
            return new StoredObject("test", objectName, size, contentType);
        }

        @Override
        public InputStream open(String bucket, String objectName) {
            return new ByteArrayInputStream(new byte[0]);
        }

        @Override
        public void remove(String bucket, String objectName) {
            removed.add(bucket + "/" + objectName);
        }
    }
}

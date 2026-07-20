package cn.datong.map.station;

import cn.datong.map.common.BusinessException;
import cn.datong.map.station.StationDtos.CreateStationRequest;
import cn.datong.map.station.StationDtos.FolderRequest;
import cn.datong.map.station.StationDtos.FolderView;
import cn.datong.map.station.StationDtos.Position;
import cn.datong.map.station.StationDtos.ProfileRequest;
import cn.datong.map.station.StationDtos.StationImageView;
import cn.datong.map.station.StationDtos.StationView;
import cn.datong.map.storage.ImageStorage;
import cn.datong.map.storage.StoredObject;
import cn.datong.map.storage.UploadPolicy;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
public class StationService {
    private final JdbcTemplate jdbcTemplate;
    private final ImageStorage storage;
    private final ObjectMapper objectMapper;
    private final WorkshopService workshops;
    private final UploadPolicy uploadPolicy;

    public StationService(JdbcTemplate jdbcTemplate, ImageStorage storage, ObjectMapper objectMapper, WorkshopService workshops,
                          UploadPolicy uploadPolicy) {
        this.jdbcTemplate = jdbcTemplate;
        this.storage = storage;
        this.objectMapper = objectMapper;
        this.workshops = workshops;
        this.uploadPolicy = uploadPolicy;
    }

    public List<StationView> listStations() {
        Map<String, StationMutable> stations = new LinkedHashMap<>();
        jdbcTemplate.query("""
                SELECT s.id, COALESCE(NULLIF(p.name, ''), s.name) AS display_name, s.name, s.auto_name, s.type,
                       s.color, s.line_name, s.mileage, s.position_x, s.position_y, s.size,
                       COALESCE(NULLIF(p.workshop_id, ''), s.default_workshop_id) AS workshop_id, COALESCE(p.notes, '') AS notes
                FROM map_station s
                LEFT JOIN station_profile p ON p.station_id = s.id
                ORDER BY s.position_y, s.position_x
                """, rs -> {
            stations.put(rs.getString("id"), new StationMutable(
                    rs.getString("id"), rs.getString("display_name"), rs.getString("auto_name"), rs.getString("type"),
                    rs.getString("color"), rs.getString("line_name"), rs.getString("mileage"),
                    rs.getDouble("position_x"), rs.getDouble("position_y"), rs.getDouble("size"),
                    workshops.publicId(rs.getString("workshop_id")), rs.getString("notes")));
        });
        Map<String, FolderMutable> folders = new HashMap<>();
        jdbcTemplate.query("""
                SELECT id, station_id, parent_id, name, sort_order FROM station_folder ORDER BY sort_order, created_at
                """, rs -> {
            FolderMutable folder = new FolderMutable(rs.getString("id"), rs.getString("station_id"), rs.getString("parent_id"), rs.getString("name"), rs.getInt("sort_order"));
            folders.put(folder.id(), folder);
        });
        folders.values().stream().sorted(Comparator.comparingInt(FolderMutable::order)).forEach(folder -> {
            if (folder.parentId() != null && folders.containsKey(folder.parentId())) {
                folders.get(folder.parentId()).children().add(folder);
            } else if (stations.containsKey(folder.stationId())) {
                stations.get(folder.stationId()).folders().add(folder);
            }
        });
        jdbcTemplate.query("""
                SELECT id, station_id, folder_id, name, content_type, size_bytes, created_at FROM station_image ORDER BY created_at
                """, rs -> {
            StationImageView image = new StationImageView(
                    rs.getString("id"), rs.getString("name"), rs.getString("content_type"), rs.getLong("size_bytes"),
                    rs.getObject("created_at", LocalDateTime.class), "/api/images/" + rs.getString("id"));
            FolderMutable folder = folders.get(rs.getString("folder_id"));
            if (folder != null) {
                folder.images().add(image);
            } else if (rs.getString("folder_id") == null && stations.containsKey(rs.getString("station_id"))) {
                stations.get(rs.getString("station_id")).overviewImages().add(image);
            }
        });
        return stations.values().stream().map(StationMutable::view).toList();
    }

    @Transactional
    public void updateProfile(String stationId, ProfileRequest request) {
        requireStation(stationId);
        String workshopCode = workshops.storageCode(request.workshopId());
        jdbcTemplate.update("""
                INSERT INTO station_profile (station_id, name, notes, workshop_id, updated_at)
                VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON DUPLICATE KEY UPDATE name = VALUES(name), notes = VALUES(notes), workshop_id = VALUES(workshop_id), updated_at = CURRENT_TIMESTAMP
                """, stationId, trim(request.name()), trim(request.notes()), workshopCode);
        if (request.color() != null) {
            String color = "blue".equals(request.color()) ? "blue" : "red";
            String type = "blue".equals(color) ? "已撤站" : "车站";
            jdbcTemplate.update("UPDATE map_station SET color = ?, type = ? WHERE id = ?", color, type, stationId);
        }
        if (request.mileage() != null) {
            String mileage = trim(request.mileage());
            if (mileage.length() > 64) throw new BusinessException("公里标不能超过64个字符");
            jdbcTemplate.update("UPDATE map_station SET mileage = ? WHERE id = ?", mileage, stationId);
        }
    }

    @Transactional
    public StationView createStation(CreateStationRequest request) {
        if (request == null) throw new BusinessException("车站名称不能为空");
        String name = trim(request.name());
        if (name.isBlank()) throw new BusinessException("车站名称不能为空");
        StationView existing = listStations().stream()
                .filter(station -> trim(station.name()).equals(name))
                .findFirst()
                .orElse(null);
        if (existing != null) return existing;
        if (request.workshopId() == null) throw new BusinessException("请选择所属车间");
        String workshopCode = workshops.storageCode(request.workshopId());
        String color = "blue".equals(request.color()) ? "blue" : "red";
        String type = "blue".equals(color) ? "已撤站" : "车站";
        String id = "station-" + UUID.randomUUID().toString().replace("-", "").substring(0, 18);
        double size = request.size() > 0 ? request.size() : 4.4;
        jdbcTemplate.update("""
                INSERT INTO map_station (id, name, auto_name, type, color, line_name, mileage, position_x, position_y, size, default_workshop_id)
                VALUES (?, ?, ?, ?, ?, '', '', ?, ?, ?, ?)
                """, id, name, name, type, color, request.x(), request.y(), size, workshopCode);
        return listStations().stream()
                .filter(station -> station.id().equals(id))
                .findFirst()
                .orElseThrow(() -> new BusinessException("车站不存在"));
    }

    @Transactional
    public FolderView addFolder(String stationId, FolderRequest request) {
        requireStation(stationId);
        String parentId = blankToNull(request.parentId());
        if (parentId != null) {
            FolderRow parent = requireFolder(parentId);
            if (!stationId.equals(parent.stationId())) throw new BusinessException("目录不属于当前站点");
            StationRules.ensureCanAddChild(folderDepth(parentId));
        }
        String id = "folder-" + UUID.randomUUID();
        int order = nextFolderOrder(stationId, parentId);
        jdbcTemplate.update("""
                INSERT INTO station_folder (id, station_id, parent_id, name, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, id, stationId, parentId, defaultName(request.name(), "新建目录"), order);
        return new FolderView(id, defaultName(request.name(), "新建目录"), order, List.of(), List.of());
    }

    @Transactional
    public void renameFolder(String folderId, String name) {
        requireFolder(folderId);
        jdbcTemplate.update("UPDATE station_folder SET name = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", defaultName(name, "新建目录"), folderId);
    }

    @Transactional
    public void deleteFolder(String folderId) {
        requireFolder(folderId);
        StationRules.ensureFolderEmpty(childCount(folderId), imageCount(folderId));
        jdbcTemplate.update("DELETE FROM station_folder WHERE id = ?", folderId);
    }

    @Transactional
    public List<StationImageView> uploadImages(String stationId, String folderId, MultipartFile[] files) throws Exception {
        requireStation(stationId);
        FolderRow folder = requireFolder(folderId);
        if (!stationId.equals(folder.stationId())) throw new BusinessException("目录不属于当前站点");
        return storeImages(stationId, folderId, files);
    }

    @Transactional
    public List<StationImageView> uploadOverviewImages(String stationId, MultipartFile[] files) throws Exception {
        requireStation(stationId);
        return storeImages(stationId, null, files);
    }

    private List<StationImageView> storeImages(String stationId, String folderId, MultipartFile[] files) throws Exception {
        uploadPolicy.validateBatch(files);
        List<StationImageView> uploaded = new ArrayList<>();
        List<StoredObject> storedObjects = new ArrayList<>();
        try {
            for (MultipartFile file : files) {
                String contentType = uploadPolicy.validateImage(file);
                SaveResult result = saveImage(stationId, folderId, file.getOriginalFilename(), contentType,
                        file.getInputStream(), file.getSize());
                storedObjects.add(result.object());
                uploaded.add(result.view());
            }
        } catch (Exception ex) {
            storedObjects.forEach(this::removeQuietly);
            throw ex;
        }
        return uploaded;
    }

    @Transactional
    public void deleteImage(String imageId) {
        ImageRow image = requireImage(imageId);
        jdbcTemplate.update("DELETE FROM station_image WHERE id = ?", imageId);
        storage.remove(image.bucket(), image.objectName());
    }

    public ImageDownload openImage(String imageId) {
        ImageRow image = requireImage(imageId);
        InputStream input = storage.open(image.bucket(), image.objectName());
        return new ImageDownload(new InputStreamResource(input), image.contentType(), image.name());
    }

    public Map<String, Object> exportData() {
        return Map.of("app", "datong-full-map-hotspots", "version", 3, "stations", listStations());
    }

    @Transactional
    public void importLegacy(MultipartFile file) throws Exception {
        uploadPolicy.validateLegacyImport(file);
        List<StoredObject> storedObjects = new ArrayList<>();
        try {
            JsonNode root = objectMapper.readTree(file.getInputStream());
            JsonNode userStations = root.path("userStations");
            if (!userStations.isObject()) throw new BusinessException("导入文件不匹配");
            userStations.fields().forEachRemaining(entry -> importStation(entry.getKey(), entry.getValue(), storedObjects));
        } catch (Exception ex) {
            storedObjects.forEach(this::removeQuietly);
            throw ex;
        }
    }

    private void importStation(String stationId, JsonNode node, List<StoredObject> storedObjects) {
        if (!stationExists(stationId)) return;
        updateProfile(stationId, new ProfileRequest(text(node, "name"), text(node, "notes"), workshops.publicId(text(node, "workshop"))));
        JsonNode folders = node.path("folders");
        if (folders.isArray()) {
            for (JsonNode folder : folders) importFolder(stationId, null, folder, 0, 1, storedObjects);
        }
    }

    private void importFolder(String stationId, String parentId, JsonNode node, int order, int depth,
                              List<StoredObject> storedObjects) {
        if (depth > 3) throw new BusinessException("导入目录最多支持三级");
        String folderId = "folder-" + UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO station_folder (id, station_id, parent_id, name, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON DUPLICATE KEY UPDATE name = VALUES(name), parent_id = VALUES(parent_id), sort_order = VALUES(sort_order), updated_at = CURRENT_TIMESTAMP
                """, folderId, stationId, parentId, defaultName(text(node, "name"), "新建目录"), order);
        JsonNode images = node.path("images");
        if (images.isArray()) {
            for (JsonNode image : images) {
                String dataUrl = text(image, "dataUrl");
                if (dataUrl != null && dataUrl.startsWith("data:")) {
                    LegacyImage legacy = LegacyImage.fromDataUrl(text(image, "name"), dataUrl);
                    String contentType = uploadPolicy.validateImageBytes(legacy.bytes(), legacy.contentType());
                    SaveResult result = saveImage(stationId, folderId, legacy.name(), contentType,
                            new ByteArrayInputStream(legacy.bytes()), legacy.bytes().length);
                    storedObjects.add(result.object());
                }
            }
        }
        JsonNode children = node.path("children");
        if (children.isArray()) {
            int index = 0;
            for (JsonNode child : children) importFolder(stationId, folderId, child, index++, depth + 1, storedObjects);
        }
    }

    private SaveResult saveImage(String stationId, String folderId, String name, String contentType, InputStream input, long size) {
        String id = "image-" + UUID.randomUUID();
        String safeName = safeName(name);
        String imageGroup = folderId == null ? "overview" : folderId;
        StoredObject object = storage.upload(input, size, contentType, "stations/%s/%s/%s-%s".formatted(stationId, imageGroup, id, safeName));
        try {
            jdbcTemplate.update("""
                    INSERT INTO station_image (id, station_id, folder_id, name, content_type, size_bytes, bucket, object_name, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                    """, id, stationId, folderId, safeName, object.contentType(), object.size(), object.bucket(), object.objectName());
        } catch (RuntimeException ex) {
            removeQuietly(object);
            throw ex;
        }
        return new SaveResult(new StationImageView(id, safeName, object.contentType(), object.size(), LocalDateTime.now(), "/api/images/" + id), object);
    }

    private void removeQuietly(StoredObject object) {
        try {
            storage.remove(object.bucket(), object.objectName());
        } catch (RuntimeException ignored) {
        }
    }

    private void requireStation(String stationId) {
        if (!stationExists(stationId)) throw new BusinessException("站点不存在");
    }

    private boolean stationExists(String stationId) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM map_station WHERE id = ?", Integer.class, stationId);
        return count != null && count > 0;
    }

    private FolderRow requireFolder(String folderId) {
        List<FolderRow> folders = jdbcTemplate.query("SELECT id, station_id, parent_id FROM station_folder WHERE id = ?",
                (rs, rowNum) -> new FolderRow(rs.getString("id"), rs.getString("station_id"), rs.getString("parent_id")), folderId);
        if (folders.isEmpty()) throw new BusinessException("目录不存在");
        return folders.getFirst();
    }

    private ImageRow requireImage(String imageId) {
        List<ImageRow> images = jdbcTemplate.query("SELECT id, name, content_type, bucket, object_name FROM station_image WHERE id = ?",
                (rs, rowNum) -> new ImageRow(rs.getString("id"), rs.getString("name"), rs.getString("content_type"), rs.getString("bucket"), rs.getString("object_name")), imageId);
        if (images.isEmpty()) throw new BusinessException("图片不存在");
        return images.getFirst();
    }

    private int folderDepth(String folderId) {
        int depth = 0;
        String current = folderId;
        while (current != null) {
            depth++;
            current = jdbcTemplate.query("SELECT parent_id FROM station_folder WHERE id = ?", rs -> rs.next() ? rs.getString(1) : null, current);
        }
        return depth;
    }

    private int imageCount(String folderId) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM station_image WHERE folder_id = ?", Integer.class, folderId);
        return count == null ? 0 : count;
    }

    private int childCount(String folderId) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM station_folder WHERE parent_id = ?", Integer.class, folderId);
        return count == null ? 0 : count;
    }

    private int nextFolderOrder(String stationId, String parentId) {
        Integer max = parentId == null
                ? jdbcTemplate.queryForObject("SELECT COALESCE(MAX(sort_order), -1) FROM station_folder WHERE station_id = ? AND parent_id IS NULL", Integer.class, stationId)
                : jdbcTemplate.queryForObject("SELECT COALESCE(MAX(sort_order), -1) FROM station_folder WHERE station_id = ? AND parent_id = ?", Integer.class, stationId, parentId);
        return (max == null ? -1 : max) + 1;
    }

    private String defaultName(String value, String fallback) {
        String text = trim(value);
        return text == null || text.isBlank() ? fallback : text;
    }

    private String trim(String value) {
        return value == null ? "" : value.trim();
    }

    private String blankToNull(String value) {
        String trimmed = trim(value);
        return trimmed.isBlank() ? null : trimmed;
    }

    private String safeName(String name) {
        String value = defaultName(name, "图片").replaceAll("[\\\\/:*?\"<>|]", "_");
        return value.length() > 120 ? value.substring(0, 120) : value;
    }

    private String text(JsonNode node, String field) {
        JsonNode value = node.path(field);
        return value.isTextual() ? value.asText() : "";
    }

    public record ImageDownload(InputStreamResource resource, String contentType, String name) {
        public MediaType mediaType() {
            return contentType == null || contentType.isBlank() ? MediaType.APPLICATION_OCTET_STREAM : MediaType.parseMediaType(contentType);
        }
    }

    private record FolderRow(String id, String stationId, String parentId) {
    }

    private record ImageRow(String id, String name, String contentType, String bucket, String objectName) {
    }

    private record SaveResult(StationImageView view, StoredObject object) {
    }

    private record StationMutable(String id, String name, String autoName, String type, String color, String line,
                                  String mileage, double x, double y, double size, Long workshopId, String notes,
                                  List<StationImageView> overviewImages, List<FolderMutable> folders) {
        StationMutable(String id, String name, String autoName, String type, String color, String line, String mileage,
                       double x, double y, double size, Long workshopId, String notes) {
            this(id, name, autoName, type, color, line, mileage, x, y, size, workshopId, notes, new ArrayList<>(), new ArrayList<>());
        }

        StationView view() {
            return new StationView(id, name, autoName, type, color, line, mileage, new Position(x, y), size, workshopId, notes,
                    overviewImages, folders.stream().sorted(Comparator.comparingInt(FolderMutable::order)).map(FolderMutable::view).toList());
        }
    }

    private record FolderMutable(String id, String stationId, String parentId, String name, int order,
                                 List<FolderMutable> children, List<StationImageView> images) {
        FolderMutable(String id, String stationId, String parentId, String name, int order) {
            this(id, stationId, parentId, name, order, new ArrayList<>(), new ArrayList<>());
        }

        FolderView view() {
            return new FolderView(id, name, order,
                    children.stream().sorted(Comparator.comparingInt(FolderMutable::order)).map(FolderMutable::view).toList(),
                    images);
        }
    }
}

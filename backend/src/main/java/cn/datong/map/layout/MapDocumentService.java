package cn.datong.map.layout;

import cn.datong.map.common.BusinessException;
import cn.datong.map.layout.MapDtos.MapDetail;
import cn.datong.map.layout.MapDtos.MapNameRequest;
import cn.datong.map.layout.MapDtos.MapSummary;
import cn.datong.map.layout.MapDtos.MarkerRequest;
import cn.datong.map.layout.MapDtos.MarkerView;
import cn.datong.map.security.CurrentUser;
import cn.datong.map.station.StationDtos.FolderView;
import cn.datong.map.station.StationDtos.Position;
import cn.datong.map.station.StationDtos.StationImageView;
import cn.datong.map.station.StationDtos.StationView;
import cn.datong.map.station.WorkshopService;
import cn.datong.map.storage.ImageStorage;
import cn.datong.map.storage.StoredObject;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class MapDocumentService {
    private final JdbcTemplate jdbcTemplate;
    private final ImageStorage storage;
    private final PdfFirstPageRenderer pdfRenderer;
    private final WorkshopService workshops;

    public MapDocumentService(JdbcTemplate jdbcTemplate, ImageStorage storage, PdfFirstPageRenderer pdfRenderer, WorkshopService workshops) {
        this.jdbcTemplate = jdbcTemplate;
        this.storage = storage;
        this.pdfRenderer = pdfRenderer;
        this.workshops = workshops;
    }

    public List<MapSummary> listMaps() {
        return jdbcTemplate.query("""
                SELECT id, name, background_url, width, height, created_at
                FROM map_document ORDER BY created_at DESC, name
                """, (rs, rowNum) -> new MapSummary(
                rs.getString("id"), rs.getString("name"), rs.getString("background_url"), rs.getInt("width"),
                rs.getInt("height"), rs.getObject("created_at", LocalDateTime.class)));
    }

    public MapDetail detail(String mapId) {
        MapRow map = requireMap(mapId);
        Map<String, StationView> stations = stationViews();
        List<MarkerView> markers = jdbcTemplate.query("""
                SELECT id, map_id, station_id, position_x, position_y, size
                FROM map_marker WHERE map_id = ? ORDER BY created_at, id
                """, (rs, rowNum) -> new MarkerView(
                rs.getString("id"), rs.getString("map_id"), rs.getDouble("position_x"), rs.getDouble("position_y"),
                rs.getDouble("size"), stations.get(rs.getString("station_id"))), mapId).stream()
                .filter(marker -> marker.station() != null)
                .toList();
        return new MapDetail(map.id(), map.name(), map.backgroundUrl(), map.width(), map.height(), markers, new ArrayList<>(stations.values()), workshops.listWorkshops());
    }

    @Transactional
    public MapDetail createMap(CurrentUser user, String name, MultipartFile pdf) throws Exception {
        requireAdmin(user);
        if (pdf == null || pdf.isEmpty()) {
            throw new BusinessException("请上传 PDF 文件");
        }
        byte[] pdfBytes = pdf.getBytes();
        PdfFirstPageRenderer.RenderedPage page = pdfRenderer.render(pdfBytes);
        String id = "map-" + UUID.randomUUID();
        String pdfName = "maps/%s/source.pdf".formatted(id);
        String pngName = "maps/%s/background.png".formatted(id);
        StoredObject pdfObject = storage.upload(pdfBytes, "application/pdf", pdfName);
        StoredObject pngObject = storage.upload(page.pngBytes(), "image/png", pngName);
        jdbcTemplate.update("""
                INSERT INTO map_document (id, name, pdf_bucket, pdf_object_name, background_bucket, background_object_name,
                                          background_url, width, height, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                """, id, defaultName(name), pdfObject.bucket(), pdfObject.objectName(), pngObject.bucket(), pngObject.objectName(),
                "/api/maps/" + id + "/background", page.width(), page.height(), user.userId());
        return detail(id);
    }

    @Transactional
    public MapSummary renameMap(CurrentUser user, String mapId, MapNameRequest request) {
        requireAdmin(user);
        requireMap(mapId);
        jdbcTemplate.update("UPDATE map_document SET name = ? WHERE id = ?", defaultName(request == null ? null : request.name()), mapId);
        return mapSummary(mapId);
    }

    @Transactional
    public void deleteMap(CurrentUser user, String mapId) {
        requireAdmin(user);
        MapRow map = requireMap(mapId);
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM map_document", Integer.class);
        if (count == null || count <= 1) {
            throw new BusinessException("至少保留一张地图");
        }
        jdbcTemplate.update("DELETE FROM map_marker WHERE map_id = ?", mapId);
        jdbcTemplate.update("DELETE FROM map_document WHERE id = ?", mapId);
        removeObject(map.pdfBucket(), map.pdfObjectName());
        removeObject(map.backgroundBucket(), map.backgroundObjectName());
    }

    @Transactional
    public MarkerView createMarker(CurrentUser user, String mapId, MarkerRequest request) {
        requireAdmin(user);
        requireMap(mapId);
        requireStation(request.stationId());
        String id = "marker-" + UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO map_marker (id, map_id, station_id, position_x, position_y, size, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, id, mapId, request.stationId(), request.x(), request.y(), markerSize(request.size()));
        return marker(mapId, id);
    }

    @Transactional
    public MarkerView updateMarker(CurrentUser user, String mapId, String markerId, MarkerRequest request) {
        requireAdmin(user);
        requireMap(mapId);
        requireStation(request.stationId());
        int updated = jdbcTemplate.update("""
                UPDATE map_marker SET station_id = ?, position_x = ?, position_y = ?, size = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ? AND map_id = ?
                """, request.stationId(), request.x(), request.y(), markerSize(request.size()), markerId, mapId);
        if (updated == 0) {
            throw new BusinessException("站点组件不存在");
        }
        return marker(mapId, markerId);
    }

    @Transactional
    public void deleteMarker(CurrentUser user, String mapId, String markerId) {
        requireAdmin(user);
        int deleted = jdbcTemplate.update("DELETE FROM map_marker WHERE id = ? AND map_id = ?", markerId, mapId);
        if (deleted == 0) {
            throw new BusinessException("站点组件不存在");
        }
    }

    public BackgroundDownload background(String mapId) {
        MapRow map = requireMap(mapId);
        if (map.backgroundBucket() == null || map.backgroundObjectName() == null) {
            throw new BusinessException("背景图不存在");
        }
        InputStream input = storage.open(map.backgroundBucket(), map.backgroundObjectName());
        return new BackgroundDownload(new InputStreamResource(input), "image/png");
    }

    private MarkerView marker(String mapId, String markerId) {
        Map<String, StationView> stations = stationViews();
        List<MarkerView> markers = jdbcTemplate.query("""
                SELECT id, map_id, station_id, position_x, position_y, size FROM map_marker WHERE id = ? AND map_id = ?
                """, (rs, rowNum) -> new MarkerView(
                rs.getString("id"), rs.getString("map_id"), rs.getDouble("position_x"), rs.getDouble("position_y"),
                rs.getDouble("size"), stations.get(rs.getString("station_id"))), markerId, mapId);
        if (markers.isEmpty() || markers.getFirst().station() == null) {
            throw new BusinessException("站点组件不存在");
        }
        return markers.getFirst();
    }

    private MapSummary mapSummary(String mapId) {
        List<MapSummary> maps = jdbcTemplate.query("""
                SELECT id, name, background_url, width, height, created_at
                FROM map_document WHERE id = ?
                """, (rs, rowNum) -> new MapSummary(
                rs.getString("id"), rs.getString("name"), rs.getString("background_url"), rs.getInt("width"),
                rs.getInt("height"), rs.getObject("created_at", LocalDateTime.class)), mapId);
        if (maps.isEmpty()) {
            throw new BusinessException("地图不存在");
        }
        return maps.getFirst();
    }

    private void removeObject(String bucket, String objectName) {
        if (bucket != null && !bucket.isBlank() && objectName != null && !objectName.isBlank()) {
            storage.remove(bucket, objectName);
        }
    }

    private void requireAdmin(CurrentUser user) {
        if (user == null || !Boolean.TRUE.equals(user.superAdmin())) {
            throw new AccessDeniedException("当前账号没有地图布局编辑权限");
        }
    }

    private MapRow requireMap(String mapId) {
        List<MapRow> maps = jdbcTemplate.query("""
                SELECT id, name, pdf_bucket, pdf_object_name, background_bucket, background_object_name, background_url, width, height
                FROM map_document WHERE id = ?
                """, (rs, rowNum) -> new MapRow(rs.getString("id"), rs.getString("name"),
                rs.getString("pdf_bucket"), rs.getString("pdf_object_name"), rs.getString("background_bucket"),
                rs.getString("background_object_name"), rs.getString("background_url"), rs.getInt("width"), rs.getInt("height")), mapId);
        if (maps.isEmpty()) {
            throw new BusinessException("地图不存在");
        }
        return maps.getFirst();
    }

    private void requireStation(String stationId) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM map_station WHERE id = ?", Integer.class, stationId);
        if (count == null || count == 0) {
            throw new BusinessException("站点不存在");
        }
    }

    private Map<String, StationView> stationViews() {
        Map<String, StationMutable> stations = new LinkedHashMap<>();
        jdbcTemplate.query("""
                SELECT s.id, COALESCE(NULLIF(p.name, ''), s.name) AS display_name, s.auto_name, s.type,
                       s.color, s.line_name, s.mileage, s.position_x, s.position_y, s.size,
                       COALESCE(NULLIF(p.workshop_id, ''), s.default_workshop_id) AS workshop_id, COALESCE(p.notes, '') AS notes
                FROM map_station s
                LEFT JOIN station_profile p ON p.station_id = s.id
                ORDER BY s.position_y, s.position_x
                """, (RowCallbackHandler) rs -> stations.put(rs.getString("id"), new StationMutable(
                rs.getString("id"), rs.getString("display_name"), rs.getString("auto_name"), rs.getString("type"),
                rs.getString("color"), rs.getString("line_name"), rs.getString("mileage"), rs.getDouble("position_x"),
                rs.getDouble("position_y"), rs.getDouble("size"), workshops.publicId(rs.getString("workshop_id")), rs.getString("notes"))));
        Map<String, FolderMutable> folders = new HashMap<>();
        jdbcTemplate.query("SELECT id, station_id, parent_id, name, sort_order FROM station_folder ORDER BY sort_order, created_at", (RowCallbackHandler) rs -> {
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
        jdbcTemplate.query("SELECT id, folder_id, name, content_type, size_bytes, created_at FROM station_image ORDER BY created_at", (RowCallbackHandler) rs -> {
            FolderMutable folder = folders.get(rs.getString("folder_id"));
            if (folder != null) {
                folder.images().add(new StationImageView(rs.getString("id"), rs.getString("name"), rs.getString("content_type"),
                        rs.getLong("size_bytes"), rs.getObject("created_at", LocalDateTime.class), "/api/images/" + rs.getString("id")));
            }
        });
        Map<String, StationView> result = new LinkedHashMap<>();
        stations.forEach((id, station) -> result.put(id, station.view()));
        return result;
    }

    private String defaultName(String name) {
        return name == null || name.isBlank() ? "未命名地图" : name.trim();
    }

    private double markerSize(double size) {
        return size > 0 ? size : 8.0;
    }

    public record BackgroundDownload(InputStreamResource resource, String contentType) {
        public MediaType mediaType() {
            return MediaType.parseMediaType(contentType);
        }
    }

    private record MapRow(String id, String name, String pdfBucket, String pdfObjectName,
                          String backgroundBucket, String backgroundObjectName, String backgroundUrl, int width, int height) {
    }

    private record StationMutable(String id, String name, String autoName, String type, String color, String line,
                                  String mileage, double x, double y, double size, Long workshopId, String notes,
                                  List<FolderMutable> folders) {
        StationMutable(String id, String name, String autoName, String type, String color, String line, String mileage,
                       double x, double y, double size, Long workshopId, String notes) {
            this(id, name, autoName, type, color, line, mileage, x, y, size, workshopId, notes, new ArrayList<>());
        }

        StationView view() {
            return new StationView(id, name, autoName, type, color, line, mileage, new Position(x, y), size, workshopId, notes,
                    folders.stream().sorted(Comparator.comparingInt(FolderMutable::order)).map(FolderMutable::view).toList());
        }
    }

    private record FolderMutable(String id, String stationId, String parentId, String name, int order,
                                 List<FolderMutable> children, List<StationImageView> images) {
        FolderMutable(String id, String stationId, String parentId, String name, int order) {
            this(id, stationId, parentId, name, order, new ArrayList<>(), new ArrayList<>());
        }

        FolderView view() {
            return new FolderView(id, name, order,
                    children.stream().sorted(Comparator.comparingInt(FolderMutable::order)).map(FolderMutable::view).toList(), images);
        }
    }
}

package cn.datong.map.layout;

import cn.datong.map.common.ApiResponse;
import cn.datong.map.layout.MapDtos.MapDetail;
import cn.datong.map.layout.MapDtos.MapNameRequest;
import cn.datong.map.layout.MapDtos.MapSummary;
import cn.datong.map.layout.MapDtos.IntervalRequest;
import cn.datong.map.layout.MapDtos.IntervalView;
import cn.datong.map.layout.MapDtos.MarkerRequest;
import cn.datong.map.layout.MapDtos.MarkerView;
import cn.datong.map.security.SecurityUtils;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.time.Duration;
import java.util.List;

@RestController
@RequestMapping("/api/maps")
public class MapDocumentController {
    private final MapDocumentService service;

    public MapDocumentController(MapDocumentService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<List<MapSummary>> maps() {
        return ApiResponse.success(service.listMaps());
    }

    @GetMapping("/{mapId}")
    public ApiResponse<MapDetail> detail(@PathVariable String mapId) {
        return ApiResponse.success(service.detail(mapId));
    }

    @GetMapping("/{mapId}/background")
    public ResponseEntity<?> background(@PathVariable String mapId) {
        MapDocumentService.BackgroundDownload background = service.background(mapId);
        return ResponseEntity.ok()
                .contentType(background.mediaType())
                .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePrivate())
                .body(background.resource());
    }

    @PostMapping
    public ApiResponse<MapDetail> create(@RequestParam("name") String name, @RequestParam("file") MultipartFile file) throws Exception {
        return ApiResponse.success(service.createMap(SecurityUtils.currentUser(), name, file));
    }

    @PutMapping("/{mapId}")
    public ApiResponse<MapSummary> rename(@PathVariable String mapId, @RequestBody MapNameRequest request) {
        return ApiResponse.success(service.renameMap(SecurityUtils.currentUser(), mapId, request));
    }

    @DeleteMapping("/{mapId}")
    public ApiResponse<Void> delete(@PathVariable String mapId) {
        service.deleteMap(SecurityUtils.currentUser(), mapId);
        return ApiResponse.success();
    }

    @PostMapping("/{mapId}/markers")
    public ApiResponse<MarkerView> createMarker(@PathVariable String mapId, @RequestBody MarkerRequest request) {
        return ApiResponse.success(service.createMarker(SecurityUtils.currentUser(), mapId, request));
    }

    @PutMapping("/{mapId}/markers/{markerId}")
    public ApiResponse<MarkerView> updateMarker(@PathVariable String mapId, @PathVariable String markerId, @RequestBody MarkerRequest request) {
        return ApiResponse.success(service.updateMarker(SecurityUtils.currentUser(), mapId, markerId, request));
    }

    @DeleteMapping("/{mapId}/markers/{markerId}")
    public ApiResponse<Void> deleteMarker(@PathVariable String mapId, @PathVariable String markerId) {
        service.deleteMarker(SecurityUtils.currentUser(), mapId, markerId);
        return ApiResponse.success();
    }

    @PostMapping("/{mapId}/intervals")
    public ApiResponse<IntervalView> createInterval(@PathVariable String mapId, @RequestBody IntervalRequest request) {
        return ApiResponse.success(service.createInterval(SecurityUtils.currentUser(), mapId, request));
    }

    @PutMapping("/{mapId}/intervals/{intervalId}")
    public ApiResponse<IntervalView> updateInterval(@PathVariable String mapId, @PathVariable String intervalId,
                                                     @RequestBody IntervalRequest request) {
        return ApiResponse.success(service.updateInterval(SecurityUtils.currentUser(), mapId, intervalId, request));
    }

    @DeleteMapping("/{mapId}/intervals/{intervalId}")
    public ApiResponse<Void> deleteInterval(@PathVariable String mapId, @PathVariable String intervalId) {
        service.deleteInterval(SecurityUtils.currentUser(), mapId, intervalId);
        return ApiResponse.success();
    }
}

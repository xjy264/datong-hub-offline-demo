package cn.datong.map.station;

import cn.datong.map.common.ApiResponse;
import cn.datong.map.station.StationDtos.FolderRequest;
import cn.datong.map.station.StationDtos.FolderView;
import cn.datong.map.station.StationDtos.CreateStationRequest;
import cn.datong.map.station.StationDtos.ProfileRequest;
import cn.datong.map.station.StationDtos.RenameFolderRequest;
import cn.datong.map.station.StationDtos.StationImageView;
import cn.datong.map.station.StationDtos.StationView;
import cn.datong.map.station.StationDtos.WorkshopRequest;
import cn.datong.map.station.StationDtos.WorkshopView;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
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

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class StationController {
    private final StationService service;
    private final WorkshopService workshops;

    public StationController(StationService service, WorkshopService workshops) {
        this.service = service;
        this.workshops = workshops;
    }

    @GetMapping("/map")
    public ApiResponse<List<StationView>> map() {
        return ApiResponse.success(service.listStations());
    }

    @GetMapping("/workshops")
    public ApiResponse<List<WorkshopView>> workshops() {
        return ApiResponse.success(workshops.listWorkshops());
    }

    @PostMapping("/workshops")
    public ApiResponse<WorkshopView> createWorkshop(@RequestBody WorkshopRequest request) {
        return ApiResponse.success(workshops.createWorkshop(request.name()));
    }

    @PutMapping("/workshops/{workshopId}")
    public ApiResponse<Void> renameWorkshop(@PathVariable Long workshopId, @RequestBody WorkshopRequest request) {
        workshops.renameWorkshop(workshopId, request.name());
        return ApiResponse.success();
    }

    @DeleteMapping("/workshops/{workshopId}")
    public ApiResponse<Void> deleteWorkshop(@PathVariable Long workshopId) {
        workshops.deleteWorkshop(workshopId);
        return ApiResponse.success();
    }

    @PutMapping("/stations/{stationId}/profile")
    public ApiResponse<Void> updateProfile(@PathVariable String stationId, @RequestBody ProfileRequest request) {
        service.updateProfile(stationId, request);
        return ApiResponse.success();
    }

    @PostMapping("/stations")
    public ApiResponse<StationView> createStation(@RequestBody CreateStationRequest request) {
        return ApiResponse.success(service.createStation(request));
    }

    @PostMapping("/stations/{stationId}/folders")
    public ApiResponse<FolderView> addFolder(@PathVariable String stationId, @RequestBody FolderRequest request) {
        return ApiResponse.success(service.addFolder(stationId, request));
    }

    @PutMapping("/folders/{folderId}")
    public ApiResponse<Void> renameFolder(@PathVariable String folderId, @RequestBody RenameFolderRequest request) {
        service.renameFolder(folderId, request.name());
        return ApiResponse.success();
    }

    @DeleteMapping("/folders/{folderId}")
    public ApiResponse<Void> deleteFolder(@PathVariable String folderId) {
        service.deleteFolder(folderId);
        return ApiResponse.success();
    }

    @PostMapping("/stations/{stationId}/folders/{folderId}/images")
    public ApiResponse<List<StationImageView>> uploadImages(@PathVariable String stationId, @PathVariable String folderId,
                                                            @RequestParam("files") MultipartFile[] files) throws Exception {
        return ApiResponse.success(service.uploadImages(stationId, folderId, files));
    }

    @DeleteMapping("/images/{imageId}")
    public ApiResponse<Void> deleteImage(@PathVariable String imageId) {
        service.deleteImage(imageId);
        return ApiResponse.success();
    }

    @GetMapping("/images/{imageId}")
    public ResponseEntity<?> image(@PathVariable String imageId) {
        StationService.ImageDownload image = service.openImage(imageId);
        String filename = URLEncoder.encode(image.name(), StandardCharsets.UTF_8).replace("+", "%20");
        return ResponseEntity.ok()
                .contentType(image.mediaType())
                .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePrivate())
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename*=UTF-8''" + filename)
                .body(image.resource());
    }

    @GetMapping("/export")
    public ApiResponse<Map<String, Object>> exportData() {
        return ApiResponse.success(service.exportData());
    }

    @PostMapping("/import")
    public ApiResponse<Void> importData(@RequestParam("file") MultipartFile file) throws Exception {
        service.importLegacy(file);
        return ApiResponse.success();
    }
}

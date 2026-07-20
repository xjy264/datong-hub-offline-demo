package cn.datong.map.station;

import java.time.LocalDateTime;
import java.util.List;

public final class StationDtos {
    private StationDtos() {
    }

    public record Position(double x, double y) {
    }

    public record StationImageView(String id, String name, String type, long size, LocalDateTime addedAt, String url) {
    }

    public record FolderView(String id, String name, int order, List<FolderView> children, List<StationImageView> images) {
    }

    public record StationView(String id, String name, String autoName, String type, String color, String line,
                              String mileage, Position position, double size, Long workshopId, String notes,
                              List<StationImageView> overviewImages, List<FolderView> folders) {
    }

    public record WorkshopView(Long id, String code, String name, String color, int sortOrder) {
    }

    public record WorkshopRequest(String name) {
    }

    public record ProfileRequest(String name, String notes, Long workshopId, String color, String mileage) {
        public ProfileRequest(String name, String notes, Long workshopId) {
            this(name, notes, workshopId, null, null);
        }

        public ProfileRequest(String name, String notes, Long workshopId, String color) {
            this(name, notes, workshopId, color, null);
        }
    }

    public record CreateStationRequest(String name, String color, Long workshopId, double x, double y, double size) {
    }

    public record FolderRequest(String parentId, String name) {
    }

    public record RenameFolderRequest(String name) {
    }
}

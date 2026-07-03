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
                              String mileage, Position position, double size, String workshopId, String notes,
                              List<FolderView> folders) {
    }

    public record ProfileRequest(String name, String notes, String workshopId) {
    }

    public record FolderRequest(String parentId, String name) {
    }

    public record RenameFolderRequest(String name) {
    }
}

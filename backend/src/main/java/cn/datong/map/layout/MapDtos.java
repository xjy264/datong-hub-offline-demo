package cn.datong.map.layout;

import cn.datong.map.station.StationDtos.StationView;
import cn.datong.map.station.StationDtos.WorkshopView;

import java.time.LocalDateTime;
import java.util.List;

public final class MapDtos {
    private MapDtos() {
    }

    public record MapSummary(String id, String name, String backgroundUrl, int width, int height, LocalDateTime createdAt) {
    }

    public record MapDetail(String id, String name, String backgroundUrl, int width, int height,
                            List<MarkerView> markers, List<IntervalView> intervals,
                            List<StationView> stations, List<WorkshopView> workshops) {
    }

    public record MapNameRequest(String name) {
    }

    public record MarkerView(String id, String mapId, double x, double y, double size, StationView station) {
    }

    public record MarkerRequest(String stationId, double x, double y, double size) {
    }

    public record IntervalView(String id, String mapId, String markerAId, String markerBId, List<String> baseStations) {
    }

    public record IntervalRequest(String markerAId, String markerBId, List<String> baseStations) {
    }
}

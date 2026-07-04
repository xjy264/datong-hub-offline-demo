package cn.datong.map.station;

import cn.datong.map.common.BusinessException;
import cn.datong.map.station.StationDtos.WorkshopView;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class WorkshopService {
    private final JdbcTemplate jdbcTemplate;

    public WorkshopService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<WorkshopView> listWorkshops() {
        return jdbcTemplate.query("""
                SELECT id, code, name, color, sort_order
                FROM map_workshop
                ORDER BY sort_order, id
                """, (rs, rowNum) -> new WorkshopView(
                rs.getLong("id"), rs.getString("code"), rs.getString("name"), rs.getString("color"), rs.getInt("sort_order")));
    }

    public Long publicId(String storedValue) {
        String value = trimToNull(storedValue);
        if (value == null) return null;
        return listWorkshops().stream()
                .filter(workshop -> workshop.code().equals(value) || String.valueOf(workshop.id()).equals(value))
                .map(WorkshopView::id)
                .findFirst()
                .orElse(null);
    }

    public String storageCode(Long publicId) {
        if (publicId == null) return null;
        return listWorkshops().stream()
                .filter(workshop -> workshop.id().equals(publicId))
                .map(WorkshopView::code)
                .findFirst()
                .orElseThrow(() -> new BusinessException("车间不存在"));
    }

    @Transactional
    public WorkshopView createWorkshop(String name) {
        String nextName = trimToNull(name);
        if (nextName == null) throw new BusinessException("车间名称不能为空");
        String code = "workshop-" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        Integer maxSort = jdbcTemplate.queryForObject("SELECT COALESCE(MAX(sort_order), 0) FROM map_workshop", Integer.class);
        int sortOrder = (maxSort == null ? 0 : maxSort) + 10;
        jdbcTemplate.update("INSERT INTO map_workshop (code, name, color, sort_order) VALUES (?, ?, ?, ?)", code, nextName, "#0f766e", sortOrder);
        return jdbcTemplate.queryForObject("""
                SELECT id, code, name, color, sort_order
                FROM map_workshop
                WHERE code = ?
                """, (rs, rowNum) -> new WorkshopView(
                rs.getLong("id"), rs.getString("code"), rs.getString("name"), rs.getString("color"), rs.getInt("sort_order")), code);
    }

    @Transactional
    public void renameWorkshop(Long id, String name) {
        String nextName = trimToNull(name);
        if (nextName == null) throw new BusinessException("车间名称不能为空");
        int updated = jdbcTemplate.update("UPDATE map_workshop SET name = ? WHERE id = ?", nextName, id);
        if (updated == 0) throw new BusinessException("车间不存在");
    }

    private String trimToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}

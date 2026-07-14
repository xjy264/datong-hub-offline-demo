package cn.datong.map.auth;

import cn.datong.map.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {
    private final AdminUserService service;

    public AdminUserController(AdminUserService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<List<AdminUserService.AdminUserView>> users() {
        return ApiResponse.success(service.listUsers());
    }

    @PutMapping("/{userId}/approval")
    public ApiResponse<Void> approval(@PathVariable long userId, @RequestBody StateRequest request) {
        service.updateApproval(userId, request.value());
        return ApiResponse.success();
    }

    @PutMapping("/{userId}/status")
    public ApiResponse<Void> status(@PathVariable long userId, @RequestBody StateRequest request) {
        service.updateStatus(userId, request.value());
        return ApiResponse.success();
    }

    @PutMapping("/{userId}/password")
    public ApiResponse<Void> password(@PathVariable long userId, @RequestBody PasswordRequest request) {
        service.resetPassword(userId, request.password(), request.confirmPassword());
        return ApiResponse.success();
    }

    public record StateRequest(String value) {
    }

    public record PasswordRequest(String password, String confirmPassword) {
    }
}

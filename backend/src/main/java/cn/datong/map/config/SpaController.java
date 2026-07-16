package cn.datong.map.config;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class SpaController {
    @GetMapping({
            "/", "/login", "/register", "/maps", "/map",
            "/workshops/{id}", "/stations/{id}", "/stations/{name}/{id}"
    })
    public String index() {
        return "forward:/index.html";
    }
}

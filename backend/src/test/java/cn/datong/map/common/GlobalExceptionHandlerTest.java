package cn.datong.map.common;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.standaloneSetup;

class GlobalExceptionHandlerTest {
    @Test
    void oversizedMultipartRequestReturnsPayloadTooLarge() throws Exception {
        standaloneSetup(new UploadController())
                .setControllerAdvice(new GlobalExceptionHandler())
                .build()
                .perform(post("/upload"))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.code").value(413));
    }

    @Test
    void missingApiReturnsNotFound() throws Exception {
        standaloneSetup(new MissingController())
                .setControllerAdvice(new GlobalExceptionHandler())
                .build()
                .perform(get("/missing"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404));
    }

    @RestController
    static class UploadController {
        @PostMapping("/upload")
        void upload() {
            throw new MaxUploadSizeExceededException(20L * 1024 * 1024);
        }
    }

    @RestController
    static class MissingController {
        @GetMapping("/missing")
        void missing() throws NoResourceFoundException {
            throw new NoResourceFoundException(HttpMethod.GET, "/missing");
        }
    }
}

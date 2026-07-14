package cn.datong.map.common;

import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

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

    @RestController
    static class UploadController {
        @PostMapping("/upload")
        void upload() {
            throw new MaxUploadSizeExceededException(20L * 1024 * 1024);
        }
    }
}

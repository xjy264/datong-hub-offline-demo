package cn.datong.map.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.forwardedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SpaControllerTest {
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new SpaController()).build();
    }

    @Test
    void forwardsKnownVueRoutesToIndex() throws Exception {
        for (String path : new String[]{"/", "/login", "/register", "/maps", "/map",
                "/workshops/12", "/stations/12", "/stations/Datong/12"}) {
            mvc.perform(get(path))
                    .andExpect(status().isOk())
                    .andExpect(forwardedUrl("/index.html"));
        }
    }

    @Test
    void doesNotSwallowApiRoutes() throws Exception {
        mvc.perform(get("/api/missing"))
                .andExpect(status().isNotFound());
    }
}

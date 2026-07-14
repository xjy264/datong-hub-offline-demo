package cn.datong.map.layout;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.InputStreamResource;

import java.io.ByteArrayInputStream;

import static org.assertj.core.api.Assertions.assertThat;

class MapDocumentControllerTest {
    @Test
    void backgroundResponsesAreCachedPrivatelyByBrowser() {
        var response = new MapDocumentController(new FakeMapDocumentService()).background("map-1");

        assertThat(response.getHeaders().getCacheControl()).contains("private", "max-age=2592000");
    }

    private static class FakeMapDocumentService extends MapDocumentService {
        FakeMapDocumentService() {
            super(null, null, null, null, null);
        }

        @Override
        public BackgroundDownload background(String mapId) {
            return new BackgroundDownload(
                    new InputStreamResource(new ByteArrayInputStream(new byte[]{1})),
                    "image/png"
            );
        }
    }
}

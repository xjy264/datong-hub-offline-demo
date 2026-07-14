package cn.datong.map.station;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.InputStreamResource;

import java.io.ByteArrayInputStream;

import static org.assertj.core.api.Assertions.assertThat;

class StationControllerTest {
    @Test
    void imageResponsesAreCachedPrivatelyByBrowser() {
        var response = new StationController(new FakeStationService(), new WorkshopService(null)).image("image-1");

        assertThat(response.getHeaders().getCacheControl()).contains("private", "max-age=2592000");
    }

    private static class FakeStationService extends StationService {
        FakeStationService() {
            super(null, null, null, null, null);
        }

        @Override
        public ImageDownload openImage(String imageId) {
            return new ImageDownload(
                    new InputStreamResource(new ByteArrayInputStream(new byte[]{1})),
                    "image/png",
                    "photo.png"
            );
        }
    }
}

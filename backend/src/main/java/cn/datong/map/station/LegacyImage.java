package cn.datong.map.station;

import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public record LegacyImage(String name, String contentType, byte[] bytes) {
    private static final Pattern DATA_URL = Pattern.compile("^data:([^;,]+)?;base64,(.*)$", Pattern.DOTALL);

    public static LegacyImage fromDataUrl(String name, String dataUrl) {
        Matcher matcher = DATA_URL.matcher(dataUrl == null ? "" : dataUrl);
        if (!matcher.matches()) {
            throw new IllegalArgumentException("导入图片格式不正确");
        }
        String contentType = matcher.group(1) == null || matcher.group(1).isBlank() ? "application/octet-stream" : matcher.group(1);
        return new LegacyImage(name == null || name.isBlank() ? "图片" : name, contentType, Base64.getDecoder().decode(matcher.group(2)));
    }
}

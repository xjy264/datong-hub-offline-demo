package cn.datong.map.storage;

import java.io.InputStream;

public interface ImageStorage {
    StoredObject upload(byte[] bytes, String contentType, String objectName);
    InputStream open(String bucket, String objectName);
    void remove(String bucket, String objectName);
}

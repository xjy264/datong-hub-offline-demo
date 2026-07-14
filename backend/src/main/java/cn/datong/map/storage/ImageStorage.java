package cn.datong.map.storage;

import java.io.InputStream;

public interface ImageStorage {
    StoredObject upload(InputStream input, long size, String contentType, String objectName);
    InputStream open(String bucket, String objectName);
    void remove(String bucket, String objectName);
}

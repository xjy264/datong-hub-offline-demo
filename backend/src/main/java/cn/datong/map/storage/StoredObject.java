package cn.datong.map.storage;

public record StoredObject(String bucket, String objectName, long size, String contentType) {
}

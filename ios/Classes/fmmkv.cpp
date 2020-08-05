#include <MMKV.h>
#include <MMKVPredef.h>
#include <android/log.h>

struct StringList {
    int64_t length;
    char** data;
};

struct ByteList {
    int64_t length;
    uint8_t* data;
};

static void (*g_mmkvLog)(int32_t level, const char* file, int32_t line, const char* function, const char* message);
static int (*g_onMMKVCRCCheckFail)(const char* mmapID);
static int (*g_onMMKVFileLengthError)(const char* mmapID);
static void (*g_onContentChangedByOuterProcess)(const char* mmapID);

static char* string2char(const std::string &str) {
    char* data = (char*) malloc(str.size() + 1);
    memcpy(data, str.data(), str.size());
    data[str.size()] = 0;
    return data;
}

static void mmkvLog(MMKVLogLevel level, const char *file, int line, const char *function, const std::string &message) {
    g_mmkvLog(level, file, line, function, string2char(message));
}

static MMKVRecoverStrategic onMMKVError(const std::string &mmapID, MMKVErrorType errorType) {
    int strategic = -1;
    if (errorType == MMKVCRCCheckFail) {
        strategic = g_onMMKVCRCCheckFail(string2char(mmapID));
    } else if (errorType == MMKVFileLength) {
        strategic = g_onMMKVFileLengthError(string2char(mmapID));
    }
    if (strategic != -1) {
        return static_cast<MMKVRecoverStrategic>(strategic);
    }
    return OnErrorDiscard;
}

static void onContentChangedByOuterProcess(const std::string& mmapID) {
    g_onContentChangedByOuterProcess(string2char(mmapID));
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int32_t native_add(int32_t x, int32_t y) {
    return x + y;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void fmmkv_initialize(char* rootDir, int32_t logLevel) {
    MMKV::initializeMMKV(rootDir, (MMKVLogLevel) logLevel);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void fmmkv_setLogLevel(int32_t level) {
    MMKV::setLogLevel((MMKVLogLevel) level);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void fmmkv_onExit() {
    MMKV::onExit();
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int64_t fmmkv_getMMKVWithID(char* mmapID, int32_t mode, char* cryptKey, char* rootPath) {
    MMKV* kv = nullptr;
    if (!mmapID) {
        return (int64_t) kv;
    }
    std::string str = std::string(mmapID);
    bool done = false;
    if (cryptKey) {
        std::string crypt = std::string(cryptKey);
        if (crypt.length() > 0) {
            if (rootPath) {
                std::string path = std::string(rootPath);
                kv = MMKV::mmkvWithID(str, mmkv::DEFAULT_MMAP_SIZE, (MMKVMode) mode, &crypt, &path);
            } else {
                kv = MMKV::mmkvWithID(str, mmkv::DEFAULT_MMAP_SIZE, (MMKVMode) mode, &crypt, nullptr);
            }
            done = true;
        }
    }
    if (!done) {
        if (rootPath) {
            std::string path = std::string(rootPath);
            kv = MMKV::mmkvWithID(str, mmkv::DEFAULT_MMAP_SIZE, (MMKVMode) mode, nullptr, &path);
        } else {
            kv = MMKV::mmkvWithID(str, mmkv::DEFAULT_MMAP_SIZE, (MMKVMode) mode, nullptr, nullptr);
        }
    }
    return (int64_t) kv;
}

extern "C" __attribute((visibility("default"))) __attribute((used))
int64_t fmmkv_getDefaultMMKV(int mode, char* cryptKey) {
    MMKV *kv = nullptr;
    if (cryptKey) {
        std::string crypt = std::string(cryptKey);
        if (!crypt.empty()) {
            kv = MMKV::defaultMMKV((MMKVMode) mode, &crypt);
        }
    }
    if (!kv) {
        kv = MMKV::defaultMMKV((MMKVMode) mode, nullptr);
    }
    return (int64_t) kv;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_checkProcessMode(int64_t handle) {
    MMKV* kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        return kv->checkProcessMode();
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
char* fmmkv_cryptKey(int64_t handle) {
    MMKV* kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        std::string cryptKey = kv->cryptKey();
        if (!cryptKey.empty()) {
            return string2char(cryptKey);
        }
    }
    return nullptr;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_reKey(int64_t handle, char* cryptKey) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        std::string newKey;
        if (cryptKey) {
            newKey = std::string(cryptKey);
        }
        return kv->reKey(newKey);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_checkReSetCryptKey(int64_t handle, char* cryptKey) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        std::string newKey;
        if (cryptKey) {
            newKey = std::string(cryptKey);
        }
        if (!cryptKey || newKey.empty()) {
            kv->checkReSetCryptKey(nullptr);
        } else {
            kv->checkReSetCryptKey(&newKey);
        }
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_pageSize() {
    return mmkv::DEFAULT_MMAP_SIZE;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
char* fmmkv_mmapId(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        return string2char(kv->mmapID());
    }
    return nullptr;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_lock(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        kv->lock();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_unlock(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        kv->unlock();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_tryLock(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv) {
        return kv->try_lock();
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_encodeBool(int64_t handle, const char* key, int32_t value) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        return kv->set((bool) value, std::string(key));
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_decodeBool(int64_t handle, const char* key, int32_t defaultValue) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv && key) {
        return kv->getBool(std::string(key), defaultValue);
    }
    return defaultValue;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_encodeInt(int64_t handle, const char* key, int64_t value) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        return kv->set((int64_t) value, key);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int64_t fmmkv_decodeInt(int64_t handle, const char* key, int64_t defaultValue) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        return kv->getInt64(key, defaultValue);
    }
    return defaultValue;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_encodeDouble(int64_t handle, const char* key, double value) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        return kv->set((double) value, key);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int64_t fmmkv_decodeDouble(int64_t handle, const char* key, double defaultValue) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        return kv->getDouble(key, defaultValue);
    }
    return defaultValue;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_encodeString(int64_t handle, const char* key, const char* value) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        return kv->set((const char*) value, key);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
char* fmmkv_decodeString(int64_t handle, const char* key, char* defaultValue) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        std::string ans;
        if (kv->getString(key, ans)) {
            return string2char(ans);
        }
    }
    return defaultValue;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_encodeStringSet(int64_t handle, const char* key, StringList* value) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        std::vector<std::string> value_vector(value->length);
        for (int i = 0; i < value->length; i++) {
            value_vector[i] = std::string(value->data[i]);
        }
        return kv->set((std::vector<std::string>) value_vector, key);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
StringList* fmmkv_decodeStringSet(int64_t handle, const char* key) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        std::vector<std::string> ans;
        if (kv->getVector(key, ans)) {
            StringList* ans_ptr = (StringList*) malloc(sizeof(StringList));
            ans_ptr->length = ans.size();
            ans_ptr->data = (char**) malloc((int64_t) ans.size() * sizeof(char*));
            for (int i = 0; i < ans.size(); i++) {
                ans_ptr->data[i] = string2char(ans[i]);
            }
            return ans_ptr;
        }
    }
    return nullptr;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_encodeUint8List(int64_t handle, const char* key, ByteList* value) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        mmkv::MMBuffer buffer = mmkv::MMBuffer(value->data, value->length);
        return kv->set(buffer, key);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
ByteList* fmmkv_decodeUint8List(int64_t handle, const char* key) {
    MMKV *kv = reinterpret_cast<MMKV*>(handle);
    if (kv && key) {
        mmkv::MMBuffer value = kv->getBytes(key);
        if (value.length() > 0) {
            ByteList* ans_ptr = (ByteList*) malloc(sizeof(ByteList));
            ans_ptr->length = value.length();
            ans_ptr->data = (uint8_t*) malloc(value.length());
            memcpy(ans_ptr->data, value.getPtr(), value.length());
            return ans_ptr;
        }
    }
    return nullptr;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_valueSize(int64_t handle, const char* key, int32_t actualSize) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv && key) {
        return kv->getValueSize(key, (bool) actualSize);
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_containsKey(int64_t handle, const char* key) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv && key) {
        return kv->containsKey(key);
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
StringList* fmmkv_allKeys(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        std::vector<std::string> keys = kv->allKeys();
        StringList* ans_ptr = (StringList*) malloc(sizeof(StringList));
        ans_ptr->length = keys.size();
        ans_ptr->data = (char**) malloc(sizeof(char*) * keys.size());
        for (int i = 0; i < keys.size(); i++) {
            ans_ptr->data[i] = string2char(keys[i]);
        }
        return ans_ptr;
    }
    return nullptr;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int64_t fmmkv_count(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        return kv->count();
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int64_t fmmkv_totalSize(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        return kv->totalSize();
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_removeValueForKey(int64_t handle, char* key) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv && key) {
        kv->removeValueForKey(key);
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_removeValuesForKeys(int64_t handle, StringList* arrKeys) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv && arrKeys) {
        std::vector<std::string> keys(arrKeys->length);
        for (int i = 0; i < arrKeys->length; i++) {
            keys[i] = std::string(arrKeys->data[i]);
        }
        kv->removeValuesForKeys(keys);
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_clearAll(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        kv->clearAll();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_trim(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        kv->trim();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_close(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        kv->close();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_clearMemoryCache(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        kv->clearMemoryCache();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_sync(int64_t handle, int32_t sync) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        kv->sync(sync ? SyncFlag::MMKV_SYNC : SyncFlag::MMKV_ASYNC);
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_isFileValid(char* mmapID) {
    if (mmapID) {
        return MMKV::isFileValid(mmapID);
    }
    return false;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int64_t fmmkv_getMMKVWithAshmemFD(char* mmapID, int32_t fd, int32_t metaFD, char* cryptKey) {
    MMKV *kv = nullptr;
    if (!mmapID || fd < 0 || metaFD < 0) {
        return (int64_t) kv;
    }
    if (cryptKey) {
        std::string crypt = std::string(cryptKey);
        if (crypt.length() > 0) {
            kv = MMKV::mmkvWithAshmemFD(mmapID, fd, metaFD, &crypt);
        }
    }
    if (!kv) {
        kv = MMKV::mmkvWithAshmemFD(mmapID, fd, metaFD, nullptr);
    }
    return (int64_t) kv;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_ashmemFD(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        return kv->ashmemFD();
    }
    return -1;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
int32_t fmmkv_ashmemMetaFD(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        return kv->ashmemMetaFD();
    }
    return -1;
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_setCallbackHandler(int32_t logReDirecting, int32_t hasCallback, void (*_g_mmkvLog) (int32_t, const char*, int32_t, const char*, const char*), int32_t (*_g_onMMKVCRCCheckFail) (const char*), int32_t (*_g_onMMKVFileLengthError) (const char*)) {
    if (logReDirecting) {
        g_mmkvLog = _g_mmkvLog;
        MMKV::registerLogHandler(mmkvLog);
    } else {
        MMKV::unRegisterLogHandler();
    }
    if (hasCallback) {
        g_onMMKVCRCCheckFail = _g_onMMKVCRCCheckFail;
        g_onMMKVFileLengthError = _g_onMMKVFileLengthError;
        MMKV::registerErrorHandler(onMMKVError);
    } else {
        MMKV::unRegisterErrorHandler();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_setWantsContentChangeNotify(int32_t needsNotify, void (*_g_setWantsContentChangeNotify) (const char*)) {
    if (needsNotify) {
        g_onContentChangedByOuterProcess = _g_setWantsContentChangeNotify;
        MMKV::registerContentChangeHandler(onContentChangedByOuterProcess);
    } else {
        MMKV::unRegisterContentChangeHandler();
    }
}

extern "C" __attribute__((visibility("default"))) __attribute((used))
void fmmkv_checkContentChangedByOuterProcess(int64_t handle) {
    MMKV *kv = reinterpret_cast<MMKV *>(handle);
    if (kv) {
        kv->checkContentChanged();
    }
}

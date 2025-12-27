--[[
    Telemetry Constants
    Shared between server and client
]]

TelemetryConstants = TelemetryConstants or {}

-- Log levels
TelemetryConstants.LOG_LEVELS = {
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5,
    FATAL = 6,
}

-- Log level names (reverse lookup)
TelemetryConstants.LOG_LEVEL_NAMES = {
    [1] = 'TRACE',
    [2] = 'DEBUG',
    [3] = 'INFO',
    [4] = 'WARN',
    [5] = 'ERROR',
    [6] = 'FATAL',
}

-- Error sources
TelemetryConstants.SOURCES = {
    SERVER = 'server',
    CLIENT = 'client',
    NUI = 'nui',
}

-- Anomaly types (for DusaTrace integration)
TelemetryConstants.ANOMALY_TYPES = {
    HIGH_ERROR_RATE = 'high_error_rate',
    SLOW_OPERATIONS = 'slow_operations',
    ERROR_SPIKE = 'error_spike',
    DATABASE_TIMEOUT = 'database_timeout',
    MEMORY_LEAK = 'memory_leak',
}

-- Sentry constants
TelemetryConstants.SENTRY = {
    VERSION = 7,
    CLIENT_NAME = 'fivem-lua/1.0',
    PLATFORM = 'other',
    LOGGER = 'dusa-ecosystem',
}

-- Breadcrumb categories
TelemetryConstants.BREADCRUMB_CATEGORY = {
    DEFAULT = 'default',
    NAVIGATION = 'navigation',
    HTTP = 'http',
    DATABASE = 'database',
    UI = 'ui',
    USER = 'user',
    DEBUG = 'debug',
}

-- Limits
TelemetryConstants.LIMITS = {
    MAX_MESSAGE_LENGTH = 500,
    MAX_BREADCRUMBS = 50,
    MAX_STACK_FRAMES = 50,
}

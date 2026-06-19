String? runtimeConfigValue(String key) => null;

/// Keeps [configured] unchanged on non-web platforms.
String applyDeploymentApiBaseUrl(String configured) => configured;

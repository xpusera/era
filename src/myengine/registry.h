#pragma once

#include <string>
#include <unordered_map>

class Registry {
public:
	/**
	 * Checks if a real C++-generated path exists in the registry.
	 */
	static bool path_exists(const std::string &real_path);

	/**
	 * Registers a real C++-generated path into the registry.
	 */
	static void register_path(const std::string &real_path);

	/**
	 * Clears the registry (mainly for tests).
	 */
	static void clear();

	/**
	 * Initializes the registry with auto-generated paths.
	 */
	static void init();

private:
	static std::unordered_map<std::string, bool> m_registered_paths;
};

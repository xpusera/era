#pragma once

#include <string>
#include <vector>
#include <unordered_map>

class Registry {
public:
	/**
	 * Checks if a real C++-generated path exists in the registry.
	 */
	static bool path_exists(const std::string &real_path);

	/**
	 * Simulated backend for registry lookups.
	 * In a real scenario, this would interact with the auto-generated
	 * C++ class/method/property mappings.
	 */
	static void register_path(const std::string &real_path);
	static void clear();

private:
	// Maps internal paths to a simple existence flag for this simulation.
	static std::unordered_map<std::string, bool> m_registered_paths;
};

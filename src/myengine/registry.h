#pragma once

#include <string>
#include <unordered_map>

class Registry {
public:
	static bool path_exists(const std::string &real_path);
	static void register_path(const std::string &real_path);
	static void clear();
	static void init();

private:
	static std::unordered_map<std::string, bool> m_registered_paths;
};

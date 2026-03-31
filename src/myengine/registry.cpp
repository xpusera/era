#include "myengine/registry.h"

std::unordered_map<std::string, bool> Registry::m_registered_paths;

bool Registry::path_exists(const std::string &real_path)
{
	auto it = m_registered_paths.find(real_path);
	return it != m_registered_paths.end() && it->second;
}

void Registry::register_path(const std::string &real_path)
{
	m_registered_paths[real_path] = true;
}

void Registry::clear()
{
	m_registered_paths.clear();
}

void register_generated_paths();

void Registry::init()
{
	register_generated_paths();
}

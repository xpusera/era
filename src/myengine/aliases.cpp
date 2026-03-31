#include "myengine/aliases.h"
#include "myengine/registry.h"
#include "log.h"
#include "porting.h"
#include "filesys.h"
#include "util/string.h"
#include <fstream>

std::unordered_map<std::string, std::string> AliasLayer::m_alias_table;

std::string AliasLayer::resolve(const std::string &path)
{
	auto it = m_alias_table.find(path);
	if (it == m_alias_table.end()) {
		return path;
	}

	const std::string &real_path = it->second;

	if (!Registry::path_exists(real_path)) {
		warningstream << "[myengine] WARNING: alias \"" << path
					  << "\" points to a path that no longer exists (\""
					  << real_path << "\"). Mod may be broken." << std::endl;
	}

	return real_path;
}

void AliasLayer::load_aliases(const std::string &filepath)
{
	std::string full_path = porting::path_share + DIR_DELIM + filepath;
	std::ifstream is(full_path);
	if (!is.good()) {
		is.open(filepath);
	}

	if (!is.good()) {
		infostream << "[myengine] INFO: Alias file not found or inaccessible: "
				   << filepath << std::endl;
		return;
	}

	std::string line;
	while (std::getline(is, line)) {
		line = trim(line);
		if (line.empty() || line[0] == '#')
			continue;

		size_t eq_pos = line.find('=');
		if (eq_pos == std::string::npos)
			continue;

		std::string stable_path = trim(line.substr(0, eq_pos));
		std::string real_path = trim(line.substr(eq_pos + 1));

		if (!stable_path.empty() && !real_path.empty()) {
			m_alias_table[stable_path] = real_path;
		}
	}

	infostream << "[myengine] INFO: Loaded " << m_alias_table.size()
			   << " aliases from " << filepath << std::endl;
}

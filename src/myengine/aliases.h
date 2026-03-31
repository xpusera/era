#pragma once

#include <string>
#include <unordered_map>

class AliasLayer {
public:
	static std::string resolve(const std::string &path);
	static void load_aliases(const std::string &filepath);

private:
	static std::unordered_map<std::string, std::string> m_alias_table;
};

#pragma once

#include <string>
#include <unordered_map>

class AliasLayer {
public:
	/**
	 * Resolves a mod-provided path to its internal generated path.
	 *
	 * @param path The stable mod-facing path.
	 * @return The internal C++-generated path if an alias exists, or the original path.
	 */
	static std::string resolve(const std::string &path);

	/**
	 * Loads alias definitions from a file.
	 *
	 * @param filepath Path to the alias definition file.
	 */
	static void load_aliases(const std::string &filepath);

private:
	// Maps stable mod path to the real internal path.
	static std::unordered_map<std::string, std::string> m_alias_table;
};

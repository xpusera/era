set(GENERATED_REGISTRY_CPP "${CMAKE_CURRENT_BINARY_DIR}/generated_registry.cpp")

add_custom_command(
	OUTPUT "${GENERATED_REGISTRY_CPP}"
	COMMAND Python3::Interpreter "${CMAKE_CURRENT_SOURCE_DIR}/scanner.py" "${PROJECT_SOURCE_DIR}/src" "${GENERATED_REGISTRY_CPP}"
	DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/scanner.py"
	COMMENT "Scanning C++ source for myengine registry paths..."
	VERBATIM
)

set(myengine_SRCS
	${CMAKE_CURRENT_SOURCE_DIR}/aliases.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/registry.cpp
	"${GENERATED_REGISTRY_CPP}"
	PARENT_SCOPE
)

set(myengine_HDRS
	aliases.h
	registry.h
	PARENT_SCOPE
)

#!/usr/bin/env bash
# =============================================================================
# Test Suite for Devcontainer Base Image & Features
# =============================================================================
# Builds the base image, verifies only expected base tools are present, then
# tests each feature by layering it on top of the base.
#
# Usage:
#   ./tests/test.sh              # run all tests
#   ./tests/test.sh base         # test base image only
#   ./tests/test.sh bun          # test a single feature
#   ./tests/test.sh duckdb       # test a single feature
#   ./tests/test.sh dbt-duckdb   # test a single feature
#   ./tests/test.sh features     # test all features only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BASE_IMAGE="devcontainer-base:test"
PASS=0
FAIL=0
ERRORS=()

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
_colour_green="\033[0;32m"
_colour_red="\033[0;31m"
_colour_yellow="\033[0;33m"
_colour_cyan="\033[0;36m"
_colour_reset="\033[0m"

log_section() {
    echo -e "\n${_colour_cyan}══════════════════════════════════════════════════════════════${_colour_reset}"
    echo -e "${_colour_cyan}  $1${_colour_reset}"
    echo -e "${_colour_cyan}══════════════════════════════════════════════════════════════${_colour_reset}"
}

log_test() {
    echo -en "  ${_colour_yellow}TEST${_colour_reset}  $1 ... "
}

pass() {
    echo -e "${_colour_green}PASS${_colour_reset}"
    PASS=$((PASS + 1))
}

fail() {
    local msg="${1:-}"
    echo -e "${_colour_red}FAIL${_colour_reset}"
    [ -n "${msg}" ] && echo -e "        ${_colour_red}↳ ${msg}${_colour_reset}"
    FAIL=$((FAIL + 1))
    ERRORS+=("$msg")
}

# Run a command inside a container from a given image.
# Usage: run_in <image> <command...>
run_in() {
    local image="$1"
    shift
    docker run --rm "${image}" "$@" 2>&1
}

# Assert a command exits 0 inside the container.
# Usage: assert_cmd <image> <description> <command...>
assert_cmd() {
    local image="$1"
    shift
    local desc="$1"
    shift
    log_test "${desc}"
    if run_in "${image}" "$@" > /dev/null 2>&1; then
        pass
    else
        fail "command failed: $*"
    fi
}

# Assert a command is not available inside the container.
# Usage: assert_cmd_absent <image> <description> <command-name>
assert_cmd_absent() {
    local image="$1"
    shift
    local desc="$1"
    shift
    local command_name="$1"
    log_test "${desc}"
    if run_in "${image}" bash -lc "command -v ${command_name}" > /dev/null 2>&1; then
        fail "unexpected command found: ${command_name}"
    else
        pass
    fi
}

# Assert a command's stdout contains a substring.
# Usage: assert_output_contains <image> <description> <substring> <command...>
assert_output_contains() {
    local image="$1"
    shift
    local desc="$1"
    shift
    local expected="$1"
    shift
    log_test "${desc}"
    local output
    if output=$(run_in "${image}" "$@" 2>&1) && echo "${output}" | grep -qi "${expected}"; then
        pass
    else
        fail "expected '${expected}' in output of: $*"
    fi
}

# Assert a user exists in the container.
# Usage: assert_user_exists <image> <username>
assert_user_exists() {
    local image="$1"
    local user="$2"
    log_test "user '${user}' exists"
    if run_in "${image}" id "${user}" > /dev/null 2>&1; then
        pass
    else
        fail "user '${user}' not found"
    fi
}

# Assert the default container user is as expected.
# Usage: assert_default_user <image> <username>
assert_default_user() {
    local image="$1"
    local user="$2"
    log_test "default user is '${user}'"
    local actual
    actual=$(run_in "${image}" whoami 2>&1 | tr -d '[:space:]')
    if [ "${actual}" = "${user}" ]; then
        pass
    else
        fail "expected '${user}', got '${actual}'"
    fi
}

# -----------------------------------------------------------------------------
# Test: Base Image Build
# -----------------------------------------------------------------------------
test_base_build() {
    log_section "Base Image – Build"
    log_test "docker build base image"
    if docker build -t "${BASE_IMAGE}" "${ROOT_DIR}/base" > /dev/null 2>&1; then
        pass
    else
        fail "base image failed to build"
        echo -e "${_colour_red}FATAL: cannot continue without a base image.${_colour_reset}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Test: Base Image – Tool Verification
# -----------------------------------------------------------------------------
test_base_tools() {
    log_section "Base Image – Tool Verification"

    # CLI tooling
    assert_cmd "${BASE_IMAGE}" "git is installed" git --version
    assert_cmd "${BASE_IMAGE}" "curl is installed" curl --version
    assert_cmd "${BASE_IMAGE}" "wget is installed" wget --version
    assert_cmd "${BASE_IMAGE}" "jq is installed" jq --version
    assert_cmd "${BASE_IMAGE}" "rg (ripgrep) is installed" rg --version
    assert_cmd "${BASE_IMAGE}" "fd is installed" fd --version
    assert_cmd "${BASE_IMAGE}" "make is installed" make --version
    assert_cmd "${BASE_IMAGE}" "openssl is installed" openssl version
    assert_cmd "${BASE_IMAGE}" "ssh is installed" ssh -V

    # Python ecosystem
    assert_cmd "${BASE_IMAGE}" "python3 is installed" python3 --version
    assert_cmd "${BASE_IMAGE}" "python symlink works" python --version
    assert_cmd "${BASE_IMAGE}" "pip3 is installed" pip3 --version
    assert_cmd "${BASE_IMAGE}" "uv is installed" uv --version

    # Optional feature tools should not leak into the base image
    assert_cmd_absent "${BASE_IMAGE}" "bun is not installed in base" bun
    assert_cmd_absent "${BASE_IMAGE}" "duckdb is not installed in base" duckdb
}

# -----------------------------------------------------------------------------
# Test: Base Image – User & Environment
# -----------------------------------------------------------------------------
test_base_user() {
    log_section "Base Image – User & Environment"

    assert_user_exists "${BASE_IMAGE}" "dev"
    assert_default_user "${BASE_IMAGE}" "dev"

    # Verify locale (single quotes intentional – expansion happens inside the container)
    # shellcheck disable=SC2016
    assert_output_contains "${BASE_IMAGE}" "locale is en_GB.UTF-8" "en_GB.UTF-8" \
        bash -c 'echo $LANG'

    # Verify sudo access
    assert_cmd "${BASE_IMAGE}" "dev user has sudo" \
        sudo -n true
}

# -----------------------------------------------------------------------------
# Feature Test Helper
# -----------------------------------------------------------------------------
# Builds a temporary test image that layers a feature's install.sh on top of
# the base image, then runs assertions against it.
#
# Usage: build_feature_image <feature-name>
# Prints the test image tag to stdout (last line).
build_feature_image() {
    local feature="$1"
    local tag="devcontainer-feature-${feature}:test"
    local feature_dir="${ROOT_DIR}/features/${feature}"
    local tmpdir

    tmpdir=$(mktemp -d)

    # Copy the install script into the build context
    cp "${feature_dir}/install.sh" "${tmpdir}/install.sh"

    # Generate a Dockerfile that layers the feature onto the base
    cat > "${tmpdir}/Dockerfile" << EOF
FROM ${BASE_IMAGE}
USER root
COPY install.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh && /tmp/install.sh
USER dev
EOF

    log_test "build feature image '${feature}'" >&2
    if docker build -t "${tag}" "${tmpdir}" > /dev/null 2>&1; then
        pass >&2
    else
        fail "feature '${feature}' failed to build on top of base" >&2
    fi

    rm -rf "${tmpdir}"
    echo "${tag}"
}

# -----------------------------------------------------------------------------
# Test: Feature – bun
# -----------------------------------------------------------------------------
test_feature_bun() {
    log_section "Feature – bun"

    local tag
    tag=$(build_feature_image "bun")

    assert_cmd "${tag}" "bun is installed" bun --version
    assert_cmd "${tag}" "bunx is installed" bunx --version

    # Base tools should still work after feature install
    assert_cmd "${tag}" "base python3 still works" python3 --version
    assert_cmd "${tag}" "base git still works" git --version
}

# -----------------------------------------------------------------------------
# Test: Feature – duckdb
# -----------------------------------------------------------------------------
test_feature_duckdb() {
    log_section "Feature – duckdb"

    local tag
    tag=$(build_feature_image "duckdb")

    assert_cmd "${tag}" "duckdb CLI is installed" duckdb --version

    # Base tools should still work after feature install
    assert_cmd "${tag}" "base python3 still works" python3 --version
    assert_cmd "${tag}" "base git still works" git --version
}

# -----------------------------------------------------------------------------
# Test: Feature – dbt-duckdb
# -----------------------------------------------------------------------------
test_feature_dbt_duckdb() {
    log_section "Feature – dbt-duckdb"

    local tag
    tag=$(build_feature_image "dbt-duckdb")

    assert_cmd "${tag}" "dbt is installed" /opt/dbt/bin/dbt --version
    assert_output_contains "${tag}" "dbt-core present in output" "dbt-core" \
        /opt/dbt/bin/dbt --version
    assert_output_contains "${tag}" "dbt-duckdb present in output" "duckdb" \
        /opt/dbt/bin/dbt --version
    assert_cmd "${tag}" "dbt venv Python works" /opt/dbt/bin/python --version

    # Base tools should still work after feature install
    assert_cmd "${tag}" "base python3 still works" python3 --version
    assert_cmd "${tag}" "base git still works" git --version
}

# -----------------------------------------------------------------------------
# Test: Feature – k8s-tools
# -----------------------------------------------------------------------------
test_feature_k8s_tools() {
    log_section "Feature – k8s-tools"

    local tag
    tag=$(build_feature_image "k8s-tools")

    assert_cmd "${tag}" "kubectl is installed" kubectl version --client
    assert_cmd "${tag}" "helm is installed" helm version
    assert_cmd "${tag}" "kustomize is installed" kustomize version

    # Verify expected versions are reported
    assert_output_contains "${tag}" "kubectl version matches" "1.32" \
        kubectl version --client
    assert_output_contains "${tag}" "helm version matches" "3.17" \
        helm version

    # Base tools should still work
    assert_cmd "${tag}" "base python3 still works" python3 --version
    assert_cmd "${tag}" "base git still works" git --version
}

# -----------------------------------------------------------------------------
# Test: Feature – postgres-client
# -----------------------------------------------------------------------------
test_feature_postgres_client() {
    log_section "Feature – postgres-client"

    local tag
    tag=$(build_feature_image "postgres-client")

    assert_cmd "${tag}" "psql is installed" psql --version
    assert_output_contains "${tag}" "psql version matches" "17" \
        psql --version

    # Base tools should still work
    assert_cmd "${tag}" "base python3 still works" python3 --version
    assert_cmd "${tag}" "base git still works" git --version
}

# -----------------------------------------------------------------------------
# Test: All Features Combined
# -----------------------------------------------------------------------------
test_all_features_combined() {
    log_section "All Features – Combined"

    local tag="devcontainer-all-features:test"
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy all install scripts
    cp "${ROOT_DIR}/features/bun/install.sh" "${tmpdir}/install-bun.sh"
    cp "${ROOT_DIR}/features/duckdb/install.sh" "${tmpdir}/install-duckdb.sh"
    cp "${ROOT_DIR}/features/dbt-duckdb/install.sh" "${tmpdir}/install-dbt-duckdb.sh"
    cp "${ROOT_DIR}/features/k8s-tools/install.sh" "${tmpdir}/install-k8s-tools.sh"
    cp "${ROOT_DIR}/features/postgres-client/install.sh" "${tmpdir}/install-postgres-client.sh"

    cat > "${tmpdir}/Dockerfile" << EOF
FROM ${BASE_IMAGE}
USER root
COPY install-bun.sh             /tmp/install-bun.sh
COPY install-duckdb.sh          /tmp/install-duckdb.sh
COPY install-dbt-duckdb.sh      /tmp/install-dbt-duckdb.sh
COPY install-k8s-tools.sh       /tmp/install-k8s-tools.sh
COPY install-postgres-client.sh /tmp/install-postgres-client.sh
RUN chmod +x /tmp/install-*.sh \
    && /tmp/install-bun.sh \
    && /tmp/install-duckdb.sh \
    && /tmp/install-dbt-duckdb.sh \
    && /tmp/install-k8s-tools.sh \
    && /tmp/install-postgres-client.sh
USER dev
EOF

    log_test "build combined image with all features"
    if docker build -t "${tag}" "${tmpdir}" > /dev/null 2>&1; then
        pass
    else
        fail "combined feature image failed to build"
        rm -rf "${tmpdir}"
        return
    fi

    rm -rf "${tmpdir}"

    # Spot-check tools from each feature
    assert_cmd "${tag}" "bun is installed" bun --version
    assert_cmd "${tag}" "duckdb is installed" duckdb --version
    assert_cmd "${tag}" "dbt is installed" /opt/dbt/bin/dbt --version
    assert_cmd "${tag}" "kubectl is installed" kubectl version --client
    assert_cmd "${tag}" "helm is installed" helm version
    assert_cmd "${tag}" "kustomize is installed" kustomize version
    assert_cmd "${tag}" "psql is installed" psql --version

    # Base tools survive all features
    assert_cmd "${tag}" "python3 still works" python3 --version
    assert_cmd "${tag}" "uv still works" uv --version
    assert_cmd "${tag}" "git still works" git --version
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
cleanup() {
    log_section "Cleanup"
    echo "  Removing test images..."
    docker rmi -f \
        "${BASE_IMAGE}" \
        "devcontainer-feature-bun:test" \
        "devcontainer-feature-duckdb:test" \
        "devcontainer-feature-dbt-duckdb:test" \
        "devcontainer-feature-k8s-tools:test" \
        "devcontainer-feature-postgres-client:test" \
        "devcontainer-all-features:test" \
        > /dev/null 2>&1 || true
    echo "  Done."
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
print_summary() {
    log_section "Summary"
    echo -e "  ${_colour_green}Passed: ${PASS}${_colour_reset}"
    echo -e "  ${_colour_red}Failed: ${FAIL}${_colour_reset}"

    if [ "${FAIL}" -gt 0 ]; then
        echo -e "\n  ${_colour_red}Failures:${_colour_reset}"
        for err in "${ERRORS[@]}"; do
            echo -e "    ${_colour_red}• ${err}${_colour_reset}"
        done
    fi

    echo ""
    if [ "${FAIL}" -eq 0 ]; then
        echo -e "  ${_colour_green}All tests passed.${_colour_reset}"
    else
        echo -e "  ${_colour_red}Some tests failed.${_colour_reset}"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local target="${1:-all}"

    case "${target}" in
        base)
            test_base_build
            test_base_tools
            test_base_user
            ;;
        bun)
            test_base_build
            test_feature_bun
            ;;
        duckdb)
            test_base_build
            test_feature_duckdb
            ;;
        dbt-duckdb)
            test_base_build
            test_feature_dbt_duckdb
            ;;
        k8s-tools)
            test_base_build
            test_feature_k8s_tools
            ;;
        postgres-client)
            test_base_build
            test_feature_postgres_client
            ;;
        features)
            test_base_build
            test_feature_bun
            test_feature_duckdb
            test_feature_dbt_duckdb
            test_feature_k8s_tools
            test_feature_postgres_client
            test_all_features_combined
            ;;
        all)
            test_base_build
            test_base_tools
            test_base_user
            test_feature_bun
            test_feature_duckdb
            test_feature_dbt_duckdb
            test_feature_k8s_tools
            test_feature_postgres_client
            test_all_features_combined
            ;;
        *)
            echo "Usage: $0 [all|base|features|bun|duckdb|dbt-duckdb|k8s-tools|postgres-client]"
            exit 1
            ;;
    esac

    print_summary
    cleanup

    [ "${FAIL}" -eq 0 ]
}

main "$@"

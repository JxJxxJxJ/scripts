#!/bin/bash
set -e

# Seteo el idioma, default es
LANG_CODE="${1:-es}"
source "langs/${LANG_CODE}.sh"

# 1. Verificar que estoy en RAMA_DESEADA (la rama que quiero hacer release)
BRANCH_ACTUAL="$(git rev-parse --abbrev-ref HEAD)"
BRANCH_DESEADA="main"
if [[ $BRANCH_ACTUAL != $BRANCH_DESEADA ]]; then
  echo "$LANG_BRANCH_MISMATCH $BRANCH_DESEADA. Actual: $BRANCH_ACTUAL"
  exit 1
fi

# 2. Veo si hay cambios en el repositorio sin commitear
# -n "String" == True si la cadena es no-vacía
if [[ -n "$(git status --porcelain)" ]]; then
  echo "$LANG_UNCOMMITTED_CHANGES"
  exit 1
fi

# 3. Verificar que los commits cumplen con el formato de Conventional Commits
echo "$LANG_VERIFYING_COMMITS"
if cog check --from-latest-tag; then
  echo "$LANG_COMMITS_OK"
elif cog check; then
  echo "$LANG_COMMITS_NO_TAGS"
else
  echo "$LANG_COMMITS_INVALID"
  exit 1
fi

# 4. Solicitar al usuario el tipo de incremento de versión
echo "$LANG_SELECT_VERSION"
echo "$LANG_MAJOR"
echo "$LANG_MINOR"
echo "$LANG_PATCH"
echo "$LANG_AUTO"
read -p "$LANG_INPUT_PROMPT" opcion

case $opcion in
1) BUMP_TYPE="--major" ;;
2) BUMP_TYPE="--minor" ;;
3) BUMP_TYPE="--patch" ;;
4) BUMP_TYPE="--auto" ;;
*)
  echo "$LANG_INVALID_OPTION"
  exit 1
  ;;
esac

# 5. Mostrar el resultado simulado del comando cog bump
echo "$LANG_SIMULATING"
cog bump $BUMP_TYPE --dry-run

# 6. Confirmar con el usuario antes de proceder
read -p "$LANG_CONFIRM" confirmacion
if [[ $confirmacion != "s" && $confirmacion != "y" ]]; then
  echo "$LANG_CANCELLED"
  exit 0
fi

# 7. Realizar el incremento de versión con Cocogitto
echo "$LANG_EXECUTING_BUMP"
cog bump $BUMP_TYPE

# 8. Obtener la nueva versión generada (ya se crearon el commit y el tag)
VERSION=$(cog -v get-version)
echo "$LANG_UPDATED_VERSION $VERSION"

# 9. Subir los cambios y tags a GitHub
echo "$LANG_PUSHING"
git push origin main --follow-tags

# 10. Crear o actualizar un release en GitHub utilizando el CHANGELOG.md generado
TAG="v$VERSION"
echo "$LANG_RELEASING $TAG..."
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "$LANG_RELEASE_EXISTS"
  gh release edit "$TAG" --notes-file CHANGELOG.md --title "$VERSION"
else
  gh release create "$TAG" --title "$VERSION" --notes-file CHANGELOG.md
fi

echo "$LANG_RELEASE_DONE"

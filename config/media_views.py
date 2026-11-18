
from pathlib import Path
import mimetypes

from django.conf import settings
from django.http import FileResponse, Http404
from django.views.decorators.http import require_GET


@require_GET
def serve_media(request, file_path):
    media_root = Path(settings.MEDIA_ROOT).resolve()

    try:
        requested_file = (media_root / file_path).resolve(strict=True)

        # Prevent access to files outside MEDIA_ROOT.
        if not requested_file.is_relative_to(media_root):
            raise Http404("Media file not found.")

        # Only serve existing files, not directories.
        if not requested_file.is_file():
            raise Http404("Media file not found.")

    except (OSError, RuntimeError, ValueError):
        raise Http404("Media file not found.")

    content_type, _ = mimetypes.guess_type(str(requested_file))

    response = FileResponse(
        requested_file.open("rb"),
        content_type=content_type or "application/octet-stream",
    )

    response["X-Content-Type-Options"] = "nosniff"

    return response

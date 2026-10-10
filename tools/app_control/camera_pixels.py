"""Independent, fixture-specific image measurement; never imported by the actor.

Requires Pillow in the developer environment. This recognizes only the fixed
beige-floor camera fixture, not physical distance, contacts or arbitrary scenes.
"""
from pathlib import Path
from statistics import median


def measure_floor(path):
    from PIL import Image
    with Image.open(Path(path)) as source:
        image = source.convert('RGB')
    if image.size != (640, 480):
        raise ValueError('Expected the unscaled 640x480 fixture camera PNG.')
    boundaries = []
    for x in range(312, 329):
        y = 479
        while y >= 0:
            r, g, b = image.getpixel((x, y))
            if not (r >= 175 and r - g >= 6 and r - b >= 18):
                break
            y -= 1
        if y in (479, -1):
            raise ValueError('Center column has no identifiable floor/wall boundary.')
        boundaries.append(y + 1)
    if max(boundaries) - min(boundaries) > 3:
        raise ValueError('Center boundary disagrees across columns; manual inspection required.')
    boundary = median(boundaries)
    pixels = 480 - boundary
    return {'boundary_y': boundary, 'floor_pixels': pixels,
            'column_range': [min(boundaries), max(boundaries)],
            'image_target': 24 <= pixels <= 38,
            'uncertainty_pixels': 1,
            'scope': 'fixed beige floor, unscaled camera, unobscured center; no physical inference'}

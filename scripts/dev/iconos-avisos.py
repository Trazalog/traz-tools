"""Iconos de los avisos al celular: assets/agentes/iconos/<clave>.png (192x192).

Los usa la app Siddhi AvisosPush (NTF_ICONOS_URL, doc/notificaciones/instalacion-avisos.md):
el aviso firmado por un agente lleva su cara; el resto, el logo de Trazalog.
Se arman desde assets/agentes/<clave>/base.webp (cabeza y hombros sobre fondo
blanco redondo, porque varios celulares no muestran la transparencia).
Uso, en una terminal local desde la raiz del repositorio:
    python scripts/dev/iconos-avisos.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / "assets/agentes/iconos"
LADO = 192


def redondo(im: Image.Image) -> Image.Image:
    fondo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    mascara = Image.new("L", (LADO, LADO), 0)
    ImageDraw.Draw(mascara).ellipse((0, 0, LADO - 1, LADO - 1), fill=255)
    blanco = Image.new("RGBA", (LADO, LADO), (255, 255, 255, 255))
    blanco.alpha_composite(im)
    fondo.paste(blanco, (0, 0), mascara)
    return fondo


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    for clave in ("quirqui", "kuntur", "faustino"):
        im = Image.open(RAIZ / f"assets/agentes/{clave}/base.webp").convert("RGBA")
        w, h = im.size
        caja = im.getbbox() or (0, 0, w, h)
        ancho = caja[2] - caja[0]
        lado = int(ancho * 0.8)                 # cabeza y hombros
        cx = (caja[0] + caja[2]) // 2
        x0 = max(0, cx - lado // 2)
        recorte = im.crop((x0, caja[1], x0 + lado, caja[1] + lado)).resize((LADO, LADO), Image.LANCZOS)
        redondo(recorte).save(DESTINO / f"{clave}.png", optimize=True)
    logo = Image.open(RAIZ / "imagenes/trazalog/logo_trazalog.png").convert("RGBA")
    logo.thumbnail((int(LADO * 0.8), int(LADO * 0.8)), Image.LANCZOS)
    lienzo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    lienzo.alpha_composite(logo, ((LADO - logo.width) // 2, (LADO - logo.height) // 2))
    redondo(lienzo).save(DESTINO / "trazalog.png", optimize=True)


if __name__ == "__main__":
    main()

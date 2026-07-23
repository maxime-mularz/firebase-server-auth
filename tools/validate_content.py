#!/usr/bin/env python3
"""Validateur du contenu narratif d'Académie d'Aldemar.

Contrôle les documents de docs/narrative/ porteurs d'un en-tête YAML :
identifiants, champs obligatoires, statuts, références croisées
(chapitres, personnages, drapeaux, objets, fichiers liés).

Usage :  python3 tools/validate_content.py       (ou : make validate-content)
Sortie : rapport lisible ; code retour 1 si au moins une ERREUR.
"""
import os
import re
import sys

try:
    import yaml
except ImportError:
    print("ERREUR : PyYAML est requis (pip install pyyaml)")
    sys.exit(2)

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
NARRATIF = os.path.join(RACINE, "docs", "narrative")

STATUTS = {"idea", "draft", "narrative_review", "technical_review",
           "creative_review", "approved", "deprecated"}
STATUTS_IMPL = {"not_started", "planned", "in_progress", "implemented",
                "tested", "blocked"}
FORME_ID = re.compile(r"^[A-Z0-9_]+$")

erreurs, avertissements = [], []


def err(fichier, msg):
    erreurs.append(f"  ERREUR  {os.path.relpath(fichier, RACINE)} : {msg}")


def avert(fichier, msg):
    avertissements.append(f"  attention  {os.path.relpath(fichier, RACINE)} : {msg}")


def lire_en_tete(chemin):
    """L'en-tête YAML entre les deux premiers '---', ou None."""
    texte = open(chemin, encoding="utf-8").read()
    if not texte.startswith("---"):
        return None
    fin = texte.find("\n---", 3)
    if fin < 0:
        err(chemin, "en-tête YAML ouvert mais jamais fermé (--- manquant)")
        return None
    try:
        donnees = yaml.safe_load(texte[3:fin])
    except yaml.YAMLError as e:
        err(chemin, f"YAML invalide : {e}")
        return None
    if not isinstance(donnees, dict):
        err(chemin, "l'en-tête YAML n'est pas un dictionnaire")
        return None
    return donnees


def liste(d, champ):
    v = d.get(champ) or []
    return v if isinstance(v, list) else [v]


# ---------------------------------------------------------------- collecte
documents = {}          # id -> (chemin, front matter)
scenes, chapitres, personnages, quetes = {}, {}, {}, {}

for dossier, _, fichiers in os.walk(NARRATIF):
    for nom in sorted(fichiers):
        if not nom.endswith(".md") or nom == "README.md":
            continue
        chemin = os.path.join(dossier, nom)
        d = lire_en_tete(chemin)
        if d is None:
            continue
        ident = d.get("id")
        if not ident:
            err(chemin, "champ obligatoire manquant : id")
            continue
        if not FORME_ID.match(str(ident)):
            err(chemin, f"identifiant mal formé : {ident} (MAJUSCULES_CHIFFRES_SOULIGNES)")
        if ident in documents:
            err(chemin, f"identifiant dupliqué : {ident} "
                        f"(déjà dans {os.path.relpath(documents[ident][0], RACINE)})")
            continue
        documents[ident] = (chemin, d)
        if str(ident).startswith("SCENE_") or "chapter" in d:
            scenes[ident] = (chemin, d)
        elif str(ident).startswith("CHAPTER_") or d.get("type") == "chapter":
            chapitres[ident] = (chemin, d)
        elif str(ident).startswith("CHAR_") or d.get("type") == "character":
            personnages[ident] = (chemin, d)
        elif str(ident).startswith("QUEST_") or d.get("type") == "quest":
            quetes[ident] = (chemin, d)

# ---------------------------------------------------- champs et statuts
OBLIGATOIRES = {
    "scene": ["id", "title", "chapter", "status", "owner", "implementation_status"],
    "chapter": ["id", "title", "status", "owner", "implementation_status"],
    "character": ["id", "name", "status", "owner"],
    "quest": ["id", "title", "status", "owner"],
}
groupes = [("scene", scenes), ("chapter", chapitres),
           ("character", personnages), ("quest", quetes)]

for genre, groupe in groupes:
    for ident, (chemin, d) in groupe.items():
        for champ in OBLIGATOIRES[genre]:
            if d.get(champ) in (None, ""):
                err(chemin, f"champ obligatoire manquant ou vide : {champ}")

for ident, (chemin, d) in documents.items():
    s = d.get("status")
    if s is not None and s not in STATUTS:
        err(chemin, f"status invalide : {s} (attendu : {', '.join(sorted(STATUTS))})")
    si = d.get("implementation_status")
    if si is not None and si not in STATUTS_IMPL:
        err(chemin, f"implementation_status invalide : {si}")

# ------------------------------------------------------ références croisées
drapeaux_poses, objets_donnes = set(), set()
for src in (scenes, quetes):
    for ident, (chemin, d) in src.items():
        drapeaux_poses.update(liste(d, "sets_flags"))
        objets_donnes.update(liste(d, "granted_items"))

chapitres_avec_scenes = set()
for ident, (chemin, d) in scenes.items():
    chap = d.get("chapter")
    if chap:
        if chap not in chapitres:
            err(chemin, f"scène rattachée à un chapitre inexistant : {chap}")
        else:
            chapitres_avec_scenes.add(chap)
    for perso in liste(d, "characters"):
        if perso not in personnages:
            err(chemin, f"personnage référencé mais non déclaré : {perso} "
                        f"(fichier attendu dans docs/narrative/characters/)")
    for drapeau in liste(d, "required_flags"):
        if drapeau not in drapeaux_poses:
            err(chemin, f"drapeau requis mais jamais posé nulle part : {drapeau}")
    for objet in liste(d, "required_items"):
        if objet not in objets_donnes:
            err(chemin, f"objet requis mais jamais accordé nulle part : {objet}")

for ident, (chemin, d) in chapitres.items():
    if ident not in chapitres_avec_scenes and d.get("status") != "deprecated":
        err(chemin, f"chapitre sans aucune scène : {ident}")

for ident, (chemin, d) in documents.items():
    for lie in liste(d, "related_files"):
        if not os.path.exists(os.path.join(RACINE, str(lie))):
            err(chemin, f"related_files pointe vers un fichier inexistant : {lie}")

# drapeaux posés mais jamais lus : simple information, pas une erreur
drapeaux_lus = set()
for ident, (chemin, d) in scenes.items():
    drapeaux_lus.update(liste(d, "required_flags"))
for drapeau in sorted(drapeaux_poses - drapeaux_lus):
    avertissements.append(f"  attention  drapeau posé mais jamais requis (normal en début de projet) : {drapeau}")

# ---------------------------------------------------------------- rapport
print(f"validate_content : {len(documents)} documents "
      f"({len(scenes)} scènes, {len(chapitres)} chapitres, "
      f"{len(personnages)} personnages, {len(quetes)} quêtes)")
for a in avertissements:
    print(a)
if erreurs:
    print()
    for e in erreurs:
        print(e)
    print(f"\n{len(erreurs)} erreur(s) — le contenu n'est pas valide.")
    sys.exit(1)
print("aucune erreur : le contenu est valide.")

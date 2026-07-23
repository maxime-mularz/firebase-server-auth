---
id: DIALOGUE_SCENE_CHXX_000
scene: SCENE_CHXX_000
type: dialogue
status: draft
owner: narrative
version: 0.1
last_updated: AAAA-MM-JJ
---

# Format des répliques

Une réplique = locuteur, texte, indications. Contraintes de forme :
~28 caractères/ligne, 3-4 lignes par fenêtre (dialogue_style.md).

```yaml
- id: DIALOGUE_SCENE_CHXX_000_001
  qui: CHAR_XXX
  texte: |
    PREMIERE LIGNE
    DEUXIEME LIGNE
  note: "[EMOTION] hésitant — pause avant la deuxième ligne"
- id: DIALOGUE_SCENE_CHXX_000_002
  qui: CHAR_YYY
  choix:
    - texte: OUI
      alors: DIALOGUE_SCENE_CHXX_000_003
    - texte: NON
      alors: DIALOGUE_SCENE_CHXX_000_004
```

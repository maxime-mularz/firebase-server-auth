# Le workflow de validation

## Cycle d'un contenu narratif

```text
idea → draft ──────────────── le Narrative Director écrit
     → narrative_review ───── relecture interne narration
     → technical_review ───── /review-scene (Claude) → review déposée
     → creative_review ────── Maxime lit scène + reviews
     → approved ───────────── SEUL état implémentable
     → (deprecated) ───────── retiré ; l'ID n'est jamais réutilisé
```

## Cycle d'implémentation

```text
approved → /implement-scene → code + tests + related_files
         → implementation_status: implemented → tested (batteries vertes)
         → playtest (/prepare-playtest) → review → réécriture éventuelle
```

## Règles transverses

1. `make validate-content` doit être vert avant tout commit touchant
   `docs/narrative/`.
2. Un `[BLOCKER]` ouvert sur une cible gèle son avancement.
3. Un désaccord entre rôles = review + réponse + si besoin
   `[DECISION_REQUIRED]` → Maxime → ADR.
4. Les builds et batteries de tests (`make roms`, `make test-snes`)
   doivent rester verts sur la branche principale de travail.
5. Chaque PR remplit le gabarit (.github/pull_request_template.md) et
   coche les validations nécessaires.

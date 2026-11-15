# Plan de portage Azeroth Stats Reborn

Ce plan découle des preuves de `AUDIT.md`. L’audit ne constitue pas un addon Reborn livrable.

## Lot 1 — Socle et capture minimale

- Isoler dossier, globals, frames, commandes, sauvegardes et outils de release.
- Ajouter dépendance Reborn et conserver temporairement la compatibilité de handlers 11200.
- Adapter difficulté, douze classes, catalogue des cartes, locale et identité serveur.
- Rebrancher progression, compteurs classiques, clôture idempotente et reprise après reload.
- Vérifier les trois racines de sauvegarde, protections et restaurations dans un environnement vierge.

Acceptation : une partie de chaque issue produit une seule entrée avec la bonne difficulté, classe, carte et identité ; reload ne crée ni doublon ni fusion de deux parties. Une donnée absente reste inconnue. Aucun fichier de l’ancien Stats n’est modifié.

## Lot 2 — Builds, rencontres et collecte enrichie

- Loadouts structurés, accessoires/rangs, descriptions de sorts et catalogue natif versionné.
- Adaptateur du vrai flux de combat, curseurs, pagination, cadence et pertes visibles.
- Rencontres, gardiens, transitions endless, effets, invocations, réanimations.
- Conserver confirmed/probable/unknown pour la mort et observed/partial/truncated pour les analyses.

Acceptation : tests de vrais contrats transcrits depuis l’API installée, données manquantes et erreurs comprises ; réconciliation des totaux sans double attribution aux boss simultanés.

## Lot 3 — Fonctions Reborn supplémentaires

- Fenêtres DPS/HPS 5–120 s, segments par checkpoints et comparaisons de builds.
- Coop par propriétaire/source et snapshots d’équipement disponibles.
- Filtres campagne/endless, difficulté, affixes et provenance du jeu.
- Export local versionné pouvant être consommé par FieldKit, facultatif.

Acceptation : fenêtres partielles signalées, soins reçus/encounter et classification procs non simulés si indisponibles. Pas d’inférence de prochain boss sans fin.

## Lot 4 — UI, qualité et distribution

- Recette visuelle des cinq thèmes Stats et du mode standard, toutes vues/infobulles.
- Vérification FR/EN puis couverture des autres langues ; noms du jeu traduits dynamiquement.
- Échelles et résolutions différentes, textes longs, tri/colonnes/pagination, premier lancement.
- FieldKit activé puis désactivé, ordres de chargement inversés, boutons minimap et overlays.
- Benchmarks de longues parties et de bases de 100/500/1000 runs, sauvegardes/restaurations.
- Adapter manifestes, génération de catalogues, contrôles de sécurité, packaging, documentation et CI à Reborn. L’ancien manifeste doit rester cohérent pendant l’audit.
- Publier d’abord un build de recette clairement identifié ; release joueurs après validation dans le vrai client.

## Scénarios client obligatoires

Installation neuve ; menu/hub sans fausse partie ; campagne normale et héroïque ; chacune des trois nouvelles classes ; pause ; choix de cartes ; boss simultanés ; gardiens absents/présents ; soins et coop ; transition endless ; changement de zone ; mort ; victoire ; abandon ; déconnexion ; reload en cours et à la fin ; redémarrage complet ; API ou champs absents ; historique volumineux ; coexistence FieldKit.

Chaque scénario doit conserver un résultat attendu et observé. Une simulation Lua ne remplace pas ce passage dans le client.

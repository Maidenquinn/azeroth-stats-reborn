# Audit du port Azeroth Stats → Azeroth Survivors Reborn

État : audit préalable terminé, port non installé et non publiable en l’état.
Date : 15 novembre 2026. Cible : API Lua du client Reborn installé (branche de jeu 0.6.5).

## Périmètre et preuves

- Base : AzerothStats 2.0.4, commit original `07a3cc29a8f112741d5a4dcc745578a34835cebc`.
- 40 modules réellement chargés par le TOC, 42 310 lignes ; les intitulés historiques V1/V2 du README ne définissent pas la version exécutée.
- Inventaire des 37 symboles AZS référencés, de 19 candidats d’API hôte et de 11 événements dans `API-INVENTORY.json`, avec fichiers, lignes et empreintes des entrées.
- Comparaison avec 174 fichiers Lua installés : couche AzerothSurvivorsAPI, cœur AzerothSurvivors et catalogue généré. Ce périmètre n’inclut pas le moteur natif C ni toutes les traductions générées.
- Guide officiel consulté : https://azreborn.com/guides/addon-api/ ; référence et empreinte dans `OFFICIAL-SOURCE.json`.
- Suite originale : 8 183 assertions hors client réussies. 16 sondes supplémentaires exécutent les véritables fonctions Lua de Reborn avec un hôte simulé et des paquets synthétiques : voir `PROBES.json`.
- Aucun SavedVariables joueur lu, aucune installation ni partie modifiée. `stats-reference` et FieldKit restent indépendants.

Une déclaration présente ne prouve pas la compatibilité sémantique. Les sondes ne valident ni le rendu, ni les réponses d’un serveur réel. La CI distante n’a pas été exécutée sur ce port, qui n’a pas encore de dépôt distant dédié.

## Ce qui reste réutilisable

L’historique local, les agrégats, les favoris, les comparaisons, les rapports, les journaux de build, les sauvegardes et les vues V2 forment une base utile. Les lecteurs classiques de dégâts et de soins acceptent les lignes natives Reborn dans les sondes. Les protections de données, limites de taille, distinction confirmé/probable/inconnu et outils de sauvegarde sont à conserver.

Les cinq thèmes et les quatorze catalogues de langue de Stats existent, mais leur contenu de jeu et leur rendu dans Reborn restent à recetter. Leur présence ne constitue pas une compatibilité vérifiée.

## Corrections nécessaires avant une première version jouable

### P0 — Isoler le produit et ses sauvegardes

`AzerothStats.toc`, `Util.lua`, `Core.lua`, `Database.lua`, les outils de packaging et les tests utilisent encore le nom original. Trois racines sont déclarées : `AzerothStatsDB`, `AzerothStatsBackup`, `AzerothStatsAutoBackup`.

Créer un dossier, un espace global, des noms de frames, des commandes et trois racines SavedVariables propres à Reborn. Identifier explicitement le jeu et la version du contrat dans les nouvelles observations. Aucune fusion automatique avec les statistiques de l’ancien jeu : mêmes noms de héros, cartes et objets ne signifient pas mêmes règles ni mêmes performances. Préserver les mécanismes de réparation et sauvegarde plutôt que repartir d’un stockage simplifié.

### P0 — Corriger difficulté et classes

`API.lua:120` lit uniquement `AZS_ZONE.heroic`. Reborn fournit `dt` pour le palier de difficulté. La sonde avec `dt=3` retourne une difficulté inconnue dans Stats.

`Safety.lua:17` n’autorise que neuf classes et `unknown`. Un moine Reborn devient effectivement `unknown`. Ajouter les identifiants exacts `monk`, `deathknight`, `demonhunter`, puis les couleurs, filtres, traductions, images, statistiques et catalogues associés. Le catalogue natif testé comporte 12 classes et 48 zones.

### P0 — Rebrancher le flux de combat

`V2CombatObserve.lua:137` exige `batch.streamId`. Le vrai `AZS_GetCombatTextEvents` exporte `{apiVersion,cursor,events,hasMore,gap}` sans ce champ. La sonde confirme le rejet d’un lot natif valide ; les tests originaux utilisent des lots artificiels avec `streamId`.

Adapter explicitement les champs : `school` au lieu de supposer `schoolMask`, `meterSource` au lieu de supposer `meterSourceKey`, et `gap` au lieu d’attendre `droppedCount`. Le flux ne fournit pas tous les ratés, réflexions ou procs espérés par les anciennes analyses : ne pas afficher zéro comme une mesure confirmée.

Le tampon natif garde au maximum 512 événements pendant 3 secondes ; une lecture sans curseur repart sur la dernière seconde. Un échantillonneur à 1 Hz peut donc perdre des événements en combat chargé : cadence dédiée, pagination bornée, reprise du curseur et indication de couverture partielle sont nécessaires. Ni ce tampon ni ses curseurs ne constituent un historique durable après `/reload`.

### P0 — Utiliser l’identité native de la partie

`Tracker.lua:410` et suivantes décident les limites par héros/classe/carte, horloge, difficulté et paquets de préparation. Cela reste heuristique. Reborn expose `AZS_API_RunId()` et le contexte du compteur ; la sonde obtient `azs:r12345678` depuis le champ serveur persistant.

Enregistrer cette identité et la provenance de sa stabilité. Vérifier reprise `/reload`, nouvelle partie sur la même carte, portail, réapparition des paquets finaux et redémarrage complet. Un identifiant de secours de session ne doit pas devenir une garantie de reprise durable. La clôture doit rester idempotente pour éviter les doubles agrégats.

### P1 — Corriger la détection des capacités

`V2Foundations.lua:38` attend `AZS_GetCombatTextCapabilities` et `AZS_GetWorldAnchorCapabilities`. Ces deux fonctions sont absentes du Lua installé et du guide consulté, alors que les getters de combat et d’ancres existent.

Détecter les véritables contrats disponibles, gérer les erreurs structurées et les états non prêts ; ne pas désactiver un sous-système sur la seule absence d’un endpoint d’un autre client. À l’inverse, la présence d’un nom de fonction ne suffit pas à annoncer une collecte complète.

### P1 — Refaire les catalogues et la localisation de jeu

`GameText.lua`, `Collection.lua`, `CreaturePortraits.lua`, `Icons.lua`, `Usage.lua` et leurs générateurs proviennent de l’ancien jeu. Le catalogue Reborn `AZS_GEN` fournit classes, sorts, zones, bijoux, amulettes et autres contenus actuels.

Séparer identifiant canonique, libellé localisé et texte brut observé. Résoudre les noms avec les dictionnaires natifs disponibles ; prévoir un repli honnête lorsqu’une traduction manque. Les textes anglais du journal de combat de compatibilité ne doivent pas être utilisés directement comme libellés FR. Recetter sorts, effets, accessoires, noms d’ennemis, graphiques, rapports et infobulles dans chaque thème.

### P1 — Capturer les accessoires et sorts depuis les bonnes sources

`Usage.lua:6` et `Items.lua` lisent cinq emplacements d’inventaire et des hyperliens localisés. Leur fonctionnement sur toutes les variantes Reborn n’est pas prouvé. Les rangs parsés depuis un suffixe romain et les anciens dictionnaires ne sont pas un contrat suffisant.

Préférer le loadout structuré `AZS_GetMeterLoadout` quand il expose la donnée demandée ; examiner les tables natives d’équipement et les descriptions des sorts comme compléments internes versionnés. Distinguer équipement de compte et accessoires temporaires de partie. Conserver rang, identifiant, texte et provenance ; ne pas recalculer les bonus avec les anciennes formules. Un bonus global comparé sur une carte de choix n’est pas nécessairement la contribution individuelle de l’objet.

### P1 — Adapter rencontres, gardiens et mode sans fin

`V2Observe.lua:50` suit les boss/final dans `AZS_UNITS` et conserve au maximum 16 rencontres ; ses prélèvements du compteur boss sont partagés, donc ne doivent pas être attribués intégralement à chaque boss simultané.

Ajouter les gardiens via `AZS_GetGuardians`/`AZS_GetLairs` et leurs états. Respecter les unités et types des champs natifs : position absente, points de vie inconnus ou gardien non apparu ne valent pas zéro ni une distance valide. En particulier, ne pas interpréter `state` numérique des boss comme un simple booléen vivant : le cœur l’utilise pour l’enrage.

Enregistrer séparément campagne et sans fin (`AZS_RUN.endless`, `endl` et contexte réellement disponible). `AZS_GetUpcomingBosses` donne les boss de campagne encore dus, pas une séquence future garantie en endless. Afficher « suite non fournie par le jeu » lorsqu’elle manque ; ne pas inventer de pourcentage ou d’horaire.

### P1 — Revalider les événements et le cycle de vie

`Core.lua:6` dépend des anciens handlers avec `this/event/arg1…`, de `CHAT_MSG_ADDON` et d’événements de combat 1.12. Reborn est un client 3.3.5a, avec une couche `Shims.lua` activée par addon pour les TOC inférieurs à 20000.

Première stratégie : garder le contrat 11200 pendant le port minimal et déclarer la dépendance `AzerothSurvivorsAPI`, puis vérifier que le nouveau dossier est reconnu par les shims. Passer directement le TOC à 30300 sans réécrire les handlers serait risqué. Le routeur `AZS.On` permet une intégration native, à dédupliquer avec les événements existants.

Valider l’ordre de chargement, hub/menu, état prêt sans création de fausse partie, choix de cartes, pause, mort, victoire, abandon et déconnexion. Les getters et tables ne remplacent pas un contrat de fraîcheur.

### P1 — Fin de partie et cause de mort

`API.lua:239` accepte les résultats `victory/defeat/left` et les champs scalaires compatibles. Une sonde de forme passe ; cela ne prouve pas encore que tous les scénarios serveur livrent les mêmes informations ni au même instant. Recetter les compteurs finaux, leur rapprochement et l’absence d’identité contradictoire.

`Nemesis.lua` s’appuie aussi sur des lignes de combat et distingue les preuves probables/confirmées. Reborn possède le journal structuré `COMBAT_LOG_EVENT_UNFILTERED` et un journal de mort interne (`DeathLog.lua`). Exploiter les événements réellement observés, y compris l’overkill lorsqu’il existe ; demander un getter public de mort finale plutôt que dépendre des widgets internes. L’absence d’événement fatal observé ne permet pas de confirmer un tueur.

### P1 — Maîtriser stockage et longues parties

Les limites existantes sont utiles : rétention entre 10 et 1000 parties, séries bornées, budgets de copie et validation. Certaines vues V2 plafonnent rencontres, sources et échantillons : rendre la troncature visible en endless. Ne pas persister le flux intégral ni recopier tout l’historique à chaque tick. Benchmarker l’amplification des sauvegardes et les transitions `/reload` avec des historiques synthétiques de 100/500/1000 parties.

### P1 — Coexistence avec FieldKit

Stats doit rester un outil d’historique et d’analyse. Son HUD et son bouton minimap doivent être facultatifs ; aucune suppression globale de l’interface native, aucun repositionnement de FieldKit. Tester les deux ordres de chargement, les noms de frames, les clics et les overlays durant les choix de cartes. L’export local existant (`InteropExport.lua`) offre une base pour une future lecture par FieldKit, après isolation du namespace et du contrat.

## Lecture de l’inventaire API

Les 37 références sont toutes couvertes par les groupes suivants ; chaque emplacement exact est dans le JSON.

- `AZS_GetMeter`, `AZS_GetHealing`, `AZS_GetBossMeter`, `AZS_GetPartyMeter`, `AZS_METER`, `AZS_HEALING`, `AZS_BOSSMETER`, `AZS_PARTY`, `AZS_TAKEN` : lecteurs présents ; dégâts/soins sondés, groupe/dégâts subis/boss et transitions à recetter. Préférer les snapshots structurés pour de nouvelles analyses.
- `AZS_GetMeterContext` : présent ; sa mention actuelle est notamment diagnostique, elle ne remplace pas l’identité heuristique du Tracker.
- `AZS_RUN`, `AZS_ZONE`, `AZS_END`, `AZS_GetPhase`, `AZS_GetRunTime`, `AZS_GetRunSummary` : présents ; sémantique de difficulté et identité à corriger, interpolation réservée à l’affichage, compteurs observés pour les records.
- `AZS_UNITS`, `AZS_REVIVE`, `AZS_PETS`, `AZS_BUFFS`, `AZS_DEBUFFS`, `AZS_SPELLS`, `AZS_STATS` : présents ; normaliser les formes, identifiants et durées. Utiliser `AZS_GetDebuffs` pour le contrat de compatibilité plutôt que supposer que la table interne a le format ancien.
- `AZS_END_UPDATED`, `AZS_SPELLS_UPDATED`, `AZS_STATS_UPDATED`, `AZS_METER_UPDATED`, `AZS_HEALING_UPDATED`, `AZS_PARTY_UPDATED`, `AZS_TAKEN_UPDATED` : produits par `Stamp`, parfois avec un nom calculé. Les quatre derniers sont marqués « non trouvés littéralement » par l’analyse statique, pas « API absente ». La sonde vérifie le stamp du compteur.
- `AZS_GetCombatTextEvents` : présent, contrat incompatible avec l’ancien observateur ; `AZS_GetCombatTextCapabilities` : absent.
- `AZS_GetWorldAnchors`, `AZS_GetDownedPartyMembers`, `AZS_GetPlayerPosition` : présents, facultatifs ; respecter erreurs, pagination, contexte monde et position inconnue. `AZS_GetWorldAnchorCapabilities` : absent.
- `AZS_SetOnTopOfScreens` : présent ; conserver un overlay configurable, sans masquer les interactions natives.

Les 19 références hôte sont classées séparément : création de frame/portrait, position curseur, horloge, son, locale, identité et zone, inventaire, carnet et textures de sorts. Elles passent souvent par `A.Call`/`pcall`, raison pour laquelle rechercher uniquement `Fonction(` aurait manqué des dépendances. Leurs signatures, les méthodes de widgets et les conventions de handlers nécessitent la recette client avec les shims ; les mocks ne les prouvent pas.

## Nouvelles fonctionnalités réalisables avec les API actuelles

1. **DPS/HPS récents sur 5–120 secondes**, pics et courbes comparables : `AZS_GetMeterCapabilities`, `AZS_GetMeterSnapshot` et contexte. Respecter la résolution d’environ une seconde, les fenêtres incomplètes et la perte de tampon lors d’un reload.
2. **Segments personnalisés** et comparaisons avant/après un changement de build : `AZS_CreateMeterCheckpoint` / `AZS_ReleaseMeterCheckpoint`, sans remise à zéro du compteur natif. Un changement observé ne prouve pas sa causalité sur les dégâts.
3. **Rapports coop par propriétaire et source**, équipement observé et identité de partie stable : snapshots/loadouts/context. Les soins reçus et les soins par rencontre ne sont pas proposés par ce contrat.
4. **Journaux de builds plus fiables** : rangs réels, bijoux de partie, descriptions, bonus observés et stats DoT lorsque fournis. Les champs de stats DoT décrivent des bonus, pas automatiquement l’uptime réel sur chaque ennemi.
5. **Chronologie de campagne et de gardiens**, affixes et transitions campagne/endless : getters dédiés et événements du routeur, sans prédiction des boss sans fin non exposés.
6. **Présence des invocations/totems, effets et réanimations** : getters natifs dédiés ; distinguer temps de présence échantillonné, activité et efficacité réelle.
7. **Analyse de mort enrichie**, à partir des événements fatals réellement captés ; l’accès stable au rapport final nécessite encore une API publique dédiée.
8. **Interop locale FieldKit facultative** : partager un résumé Stats documenté pour un HUD, sans nouvelle collecte concurrente ni envoi réseau.

La couche structurée déclare actuellement tous les procs `non_proc` : ce n’est pas une classification fiable pour mesurer « dégâts sans procs ». Les graphiques et classements doivent porter cette réserve plutôt qu’une fausse précision.

## Besoins à demander au développeur du jeu

- État endless public documenté : cycle/vague, prochain événement et prochaine cible lorsqu’ils sont effectivement définis, progression et condition de déclenchement.
- Résumé final immuable identifié par runId, notification de disponibilité et politique de replay après reload ; causes de mort structurées, identités stables et overkill.
- Capacités/version/limites des flux de combat et des ancres, identifiant de session, pertes chiffrées et continuité documentée.
- Soins reçus, soins par rencontre et vraie provenance/classification des procs si le moteur les connaît.
- Loadout et bonus effectifs versionnés, rangs, identifiants canoniques, contributions des bijoux et détails des DoT, avec indication explicite de disponibilité.
- Catalogue public d’interactifs incluant le « cristal de faille rassemblé », ses positions/états et ses changements. Utile aux marqueurs FieldKit et à un journal d’objectifs Stats ; ne pas en déduire l’existence depuis une notification traduite.
- Droits d’usage et stabilité documentés des catalogues générés et dictionnaires de traduction, aujourd’hui accessibles comme détails d’implémentation.

## Reproduire

Depuis le dépôt `stats-reborn`, avec les dépendances de `requirements-dev.txt` :

```powershell
python tools/checks.py
python tools/audit_reborn.py --game 'H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors'
python tools/probe_reborn.py --game 'H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors'
```

Les deux derniers scripts ne lisent que les sources Lua publiques installées. Ils ne doivent pas être lancés par la CI publique sans disposer légalement de ces entrées. Pour la CI du port, produire de petits fixtures de contrat ciblés et documentés ; ne pas redistribuer tout le client.

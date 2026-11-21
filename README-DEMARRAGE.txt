CONFAM — MUSIC & COMMUNITY
La musique nous rassemble.

VERSION 2 — INSCRIPTION CONTEXTUELLE ET IDENTITÉ FEU

NOUVEAUTÉS
- Le Feed reste accessible sans compte.
- Connexion / inscription dans une fenêtre séparée, affichée lorsqu’un visiteur veut publier, aimer, commenter, suivre ou ouvrir son compte.
- Inscription en deux étapes : informations de base, puis choix obligatoire du profil Artist ou Music Lover.
- Le choix est enregistré dans Supabase et dans confam_profiles.role.
- Artist : accès à la publication audio et au bouton de création Face-Off (module Face-Off à finaliser).
- Music Lover : découverte, écoute, réactions, commentaires, abonnements et publications texte/image.
- Palette chaude : orange feu, rouge corail, ambre et fond brun-noir.
- Site installable comme application PWA.

FICHIERS
- index.html : interface du site
- styles.css : identité visuelle responsive
- app.js : logique de l’application
- config.js : configuration publique Supabase
- supabase-setup.sql : tables, trigger de profil, règles RLS et buckets
- manifest.webmanifest / sw.js / favicon.svg : installation PWA

CONFIGURATION SUPABASE
1. Ouvrir ton projet Supabase.
2. Aller dans SQL Editor > New query.
3. Ouvrir supabase-setup.sql, copier tout le contenu, puis cliquer Run.
4. Dans Project Settings > API, copier l’URL du projet et la clé Publishable.
5. Remplacer les deux valeurs dans config.js.
6. Ne jamais utiliser la clé service_role / secret dans config.js.

TEST LOCAL
- Extraire le ZIP.
- Ouvrir le dossier dans VS Code.
- Lancer Live Server sur index.html.
- La fenêtre de connexion n’apparaît pas au chargement ; elle s’ouvre à la demande.

PUBLICATION CLOUDFLARE PAGES
- Déployer le contenu du dossier CONFAM (pas le dossier parent).
- Si l’ancienne version reste affichée, recharger sans cache ou fermer puis rouvrir le navigateur.

LIMITES
- Le rôle adapte certaines fonctions de l’interface.
- Inbox, Activity et Face-Off restent à compléter.
- La restriction audio est actuellement une adaptation de l’interface, pas une protection serveur. Une migration RLS devra imposer les permissions par rôle avant une ouverture publique à grande échelle.
- Les fichiers audio et images sont servis par les buckets publics configurés dans le SQL.

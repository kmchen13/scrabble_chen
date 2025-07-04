# scrabble_chen

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

La brache expectClient est une tentative de:
    - définir un partenaire expectClientName et expectHostName au moment de la connexion des joueurs.
    - modulariser encore la couche réseau.
Mais le code n'est pas terminé et contient plusieurs incohérences. Je le commit pour mémoire.
Voici le shéma visé:
démarrage d'une partie comme je le vois:

Etape0:
    Les joueurs voient le menu principal "héberger une partie", "Rejoindre une partie". Ils cliquent sur l'un d'eux.
    
Etape1: broadcast, le serveur emet une proposition de partie
    "héberger une partie" demande au joueur si on connait le nom d'un partenaire, démarre hostscreen avec un EXPECTCLIENTUSERNAME qui peut être vide si le joueur n'a rien répondu.

    hostscreen lance scrabbleServer.broadcast() qui définit $IP selon les données de son système et $HOSTUSERNAME selon settings.get('username')

    scrabbleServer.brodcast, selon settings.communicationMode lance localServer.broadcast() ou relayServer.broadcast()

    localServer.broadcast broadcast le message "SCRABBLE_HOST:$IP:$HOSTUSERNAME:$EXPECTCLIENTUSERNAME" à travers le réseau local puis se met en attente de voir un message de la forme  "SCRABBLE_CLIENT:$IP:$CLIENTUSERNAME:$EXPECTHOSTUSERNAME"

    relayServer.broadcast demande l'établissement d'une connexion en tant qu'HOST auprès du serveur distant avec son IP, HOSTUSERNAME et EXPECTCLIENTUSERNAME

Etape2: Connexion client-hôte
    "Rejoindre une partie" demande si on connait le nom d'un partenaire, démarre joinscreen avec un EXPECTHOSTUSERNAME qui peut être vide si le joueur n'a rien répondu
    
    joinscreen lance scrabbleClient.join($EXPECTHOSTUSERNAME) qui définit $IP selon les données de son système et $CLIENTUSERNAME  selon settings.get('username')
    
    scrabbleClient.join(), selon settings.communicationMode lance localClient.join($IP,$CLIENTUSERNAME,EXPECTHOSTUSERNAME) ou relayClient.join($IP,$CLIENTUSERNAME,EXPECTHOSTUSERNAME)
        
    localServer.join() se met en attente de voir un message "SCRABBLE_HOST:*:*:*" à travers le réseau local et le parse. Si $HOSTUSERNAME = $EXPECTHOSTUSERNAME ou si $EXPECTCLIENTUSERNAME est null il broadcast un message "SCRABBLE_CLIENT:$IP:$CLIENTUSERNAME:$EXPECTHOSTUSERNAME"

    relayServer.join() demande l'établissement d'une connexion en tant que CLIENT auprès du serveur distant,  avec son $IP, $HOSTUSERNAME et $EXPECTCLIENTUSERNAME.
    
Etape3: Lancement du jeu
    Lorsque le localServeur voit un message "SCRABBLE_CLIENT:*:*:*", si $EXPECTCLIENTUSERNAME = $CLIENTUSERNAME et $EXPECTHOSTUSERNAME = settings.get('username') ou si EXPECTHOSTUSERNAME et EXPECTCLIENTUSERNAME sont nulls il lance gameScreen.init(CLIENTUSERNAME, HOSTUSERNAME)
    
     Lorsque le serveur distant établit une connexion entre clients et hôtes selon la même logique que localServer.Join() il emet une requête "CONNECTED:CLIENTUSERNAME, HOSTUSERNAME" au relayServer qui lance gameScreen(game_initializer(CLIENTUSERNAME, HOSTUSERNAME)

Etape4:
    Le game screen est executé pour chaque joueur à son tour, met à jour le gameState qu'il transmet à l'autre joueur.
    
Peux tu revoir tous les fichiers évoqués en fonction de ça ?
    
Etape5:
    Lorsqu'un joueur joue ses dernières lettres, la partie est terminée et le résultat affiché.
    Un bouton permet de revenir au menu principal
    
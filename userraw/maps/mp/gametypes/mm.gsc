#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
/*
    Michael Myers
    Myers objective: Kill all survivors
    Survivors objective: Don't get killed by Michael Myer
    Round ends:	When survivor team is eliminated or roundlength time is reached
    Map ends:	When one team reaches the score limit, or time limit or round limit is reached
    Respawning:	Players remain dead for the round and will respawn at the beginning of the next round

    Level requirements
    ------------------
        Spawnpoints:
            classname		mp_tdm_spawn
            All players spawn from these. The spawnpoint chosen is dependent on the current locations of teammates and enemies
            at the time of spawn. Players generally spawn behind their teammates relative to the direction of enemies.

        Spectator Spawnpoints:
            classname		mp_global_intermission
            Spectators spawn from these and intermission is viewed from these positions.
            Atleast one is required, any more and they are randomly chosen between.

*/

/*QUAKED mp_tdm_spawn (0.0 0.0 1.0) (-16 -16 0) (16 16 72)
Players spawn away from enemies and near their team at one of these positions.*/

main()
{
    if(getdvar("mapname") == "mp_background")
        return;
    
    maps\mp\gametypes\_globallogic::init();
    maps\mp\gametypes\_callbacksetup::SetupCallbacks();
    maps\mp\gametypes\_globallogic::SetupCallbacks();

    level.callbackPlayerDamage = ::Callback_PlayerDamage;
    
    registerRoundSwitchDvar( level.gameType, 0, 0, 9 );
    registerTimeLimitDvar( level.gameType, 10, 0, 1440 );
    registerScoreLimitDvar( level.gameType, 1, 0, 500 );
    registerRoundLimitDvar( level.gameType, 0, 0, 12 );
    registerWinLimitDvar( level.gameType, 4, 0, 12 );
    registerNumLivesDvar( level.gameType, 1, 0, 10 );
    registerHalfTimeDvar( level.gameType, 0, 0, 1 );
    
    setDvar("ui_allow_teamchange", 0);
    setDvar("scr_game_hardpoints", 0);
    setDvar( "jump_height", "100");
    setDvar( "jump_slowdownEnable", "0" );
    setDvar( "g_gravity", "600");

    level.objectiveBased = true;
    level.teamBased = true;
    level.onStartGameType = ::onStartGameType;
    level.getSpawnPoint = ::getSpawnPoint;
    level.onPlayerKilled = ::onPlayerKilled;
    level.onDeadEvent = ::onDeadEvent;
    level.onOneLeftEvent = ::onOneLeftEvent;
    level.onNormalDeath = ::onNormalDeath;
    level.onTimeLimit = ::onTimeLimit;

    level.autoassign = ::menuAutoAssign; //maps\mp\gametypes\_menus::menuAutoAssign;
	//level.spectator = maps\mp\gametypes\_menus::menuSpectator;
	//level.class = maps\mp\gametypes\_menus::menuClass;
	//level.allies = maps\mp\gametypes\_menus::menuAllies;
	//level.axis = maps\mp\gametypes\_menus::menuAxis;

    level.customClassCB = false;
}


onStartGameType()
{	
    setClientNameMode( "auto_change" );
    
    setObjectiveText( "axis", &"OBJECTIVES_MM_MYERS" );
    setObjectiveText( "allies", &"OBJECTIVES_MM_SURVIVORS" );

    if ( level.splitscreen )
    {
        setObjectiveScoreText( "axis", &"OBJECTIVES_MM_MYERS" );
        setObjectiveScoreText( "allies", &"OBJECTIVES_MM_SURVIVORS" );
    }
    else
    {
        setObjectiveScoreText( "axis", &"OBJECTIVES_MM_MYERS_SCORE" );
        setObjectiveScoreText( "allies", &"OBJECTIVES_MM_MYERS_SCORE" );
    }
    setObjectiveHintText( "axis", &"OBJECTIVES_MM_MYERS_HINT" );
    setObjectiveHintText( "allies", &"OBJECTIVES_MM_SURVIVORS_HINT" );

    level.spawnMins = ( 0, 0, 0 );
    level.spawnMaxs = ( 0, 0, 0 );

    //NOTE: Might need to take the DM Spawnlogics, so every player is spread.
    maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_allies_start" );
    maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_axis_start" );
    maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
    maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );
    
    level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
    setMapCenter( level.mapCenter );
    
    allowed[0] = level.gameType;
    maps\mp\gametypes\_gameobjects::main(allowed);

    setDvar("g_TeamName_Allies", "Survivors");
    setDvar("g_TeamName_Axis", "Michael Myers");
    
    maps\mp\gametypes\_rank::registerScoreInfo( "win", 2 );
    maps\mp\gametypes\_rank::registerScoreInfo( "loss", 1 );
    maps\mp\gametypes\_rank::registerScoreInfo( "tie", 1.5 );
    
    maps\mp\gametypes\_rank::registerScoreInfo( "kill", 50 );

    level thread onPrematchOver();
    level thread onPlayerConnect();

    // The amount of time to wait for people to spawn.
    setDvarIfUninitialized( "scr_mm_time", 30 );
}


onPrematchOver()
{
    for( ;; )
    {
        self waittill("prematch_over");

        self thread monitorMyersTeam();
        //self thread monitorTeams();

        //level.firstMyer = level.players[randomInt( level.players.size )];
        //level.firstMyer changeTeam( "axis" );
        //level.firstMyer playSound( "mp_defeat" );
        //level.firstMyer thread doMyerCountdown();
    }
}


monitorMyersTeam()
{
    self endon( "game_ended" );
    self endon( "myer_picked" );

    for(;;) {
        players = maps\mp\gametypes\_teams::CountPlayers();

        if(players["axis"] == 0 && level.players.size > 0)
        {
            level.myer = level.players[ randomInt( level.players.size ) ];
            self notify("myer_picked");
            level.myer changeTeam( "axis" );
            //level.myer playSound( "mp_defeat" );
            //level.myer thread doMyerCountdown();
        }

        //waittill("myer_picked");

        //self notify("myer_picked");

        /*if(players["axis"] > 1)
        {
            iprintln("[WARN]: axis team: " + players["axis"] + " > 1, moving player back to allies");

            // Change all non myer players back to allies.
            for ( index = 0; index < level.players.size; index++ ) {
                player = level.players[index];
                
                // Check if this the player we are looking for
                if ( player getEntityNumber() != level.myer getEntityNumber() ) {
                    player changeTeam("allies");
                    //break;
                }
            }
        }*/

        wait 0.05;
    }
}
    

// NOTE: Make variable wait time.
doMyerCountdown()
{
    self endon( "disconnect" );
    self endon( "game_ended" );
    
    //wait 0.1;

    level.myerReleased = false;

    maps\mp\gametypes\_gamelogic::pauseTimer();

    // Freeze myer, so survivers have some time to run away.
    self freezeControls(true);
    self VisionSetNakedForPlayer( "black_bw", 1.5 );

    // Start final countdown!
    iPrintlnBold( "^9" + self.name + "  ^1is Michael Myers!");
    wait 5;
    iPrintlnBold( self.name + "  ^2Will be released in 15 seconds!" );
    wait 5;
    iPrintlnBold( self.name + "  ^3Will be released in 10 seconds!" );
    wait 10;
    iPrintlnBold( self.name + "  ^1Has been released!" );

    // They got enough time to get away, RELEASE THE BAIT
    self VisionSetNakedForPlayer( getDvar("mapname"), .1 );
    self freezeControls(false);

    level.myerReleased = true;

    maps\mp\gametypes\_gamelogic::resumeTimer();
}

onPlayerConnect()
{
    self endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );

        //iprintln(isDefined( player.team ));

        // TODO: Change function logic
        // Check if player is in a team
        //    if player is in a team already, continue to onPlayerSpawned() thread
        //    else check axis team and start onJoinedTeam() thread
        //       if it has one player, let the player go to allies.
        //       else let player go to axis.

        setDvar("ui_allow_teamchange", 0);
        setDvar( "jump_height", "100");
        setDvar( "jump_slowdownEnable", "0" );
        setDvar( "g_gravity", "600");

        player thread onJoinedTeam();
        player thread onPlayerSpawned();
        
        //if( !( isDefined( player.team ) || isDefined( player.pers["team"] ) || isDefined( player.sessionteam ) ) )
        //{
            player changeTeam("allies");
        //}

        //player thread doConnect();
        //player thread onJoinedTeam();

        //if(game["roundsPlayed"] > 0 ) // should actually just check the team but what ever...
        //{
        //    player thread onPlayerSpawned();
        //}
    }
}

onJoinedTeam()
{
    self endon("disconnect");
    self endon("game_ended");

    for( ;; )
    {
        self waittill("joined_team");

        wait 0.1;

        self notify("menuresponse", "changeclass", "class1");
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    self endon( "game_ended" );

    for(;;)
    {
        self waittill("spawned_player");

        wait 0.1;

        switch(self.sessionteam)
        {
            case "axis":
            self thread doMyer();
            break;
            case "allies":
            self thread doSurvivor();
            break;
        }
    }
}

checkTeam()
{
    self endon ("disconnected");
    self endon ("death");
    self endon ("game_ended");
    if( self.sessionteam == "axis" && ( self getEntityNumber() != level.myer getEntityNumber() ) )
    {
        iprintln("[WARN]: onPlayerSpawned(): " + self.name + " joined axis without being a myer? Moving to allies");
        self thread changeTeam("allies");
        return;
    }
}


getSpawnPoint()
{
    spawnteam = self.pers["team"];
    if ( game["switchedsides"] )
        spawnteam = getOtherTeam( spawnteam );

    if ( level.inGracePeriod )
    {
        if ( getDvar( "mapname" ) == "mp_shipment_long" )
        {
            spawnPoints = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_cha_spawn_" + spawnteam + "_start" );
            spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( spawnPoints );
        }
        else
        {
            spawnPoints = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_tdm_spawn_" + spawnteam + "_start" );
            spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( spawnPoints );
        }
    }
    else
    {
        spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( spawnteam );
        spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam( spawnPoints );
    }
    
    return spawnPoint;
}

doSurvivor()
{
    self endon( "death" );
    self endon( "disconnect" );

    self takeAllWeapons();
    self _clearPerks();
    wait .1;

    self giveWeapon( "usp_tactical_mp" );
    wait 1;
    self setWeaponAmmoClip( "usp_tactical_mp", 0 );
    self setWeaponAmmoStock( "usp_tactical_mp", 0 );
    self switchToWeapon( "usp_tactical_mp" );

    //self _setPerk( "specialty_extendedmelee" );
    self _setPerk( "specialty_heartbreaker" );
    self _setPerk( "specialty_coldblooded" );
    self _setPerk( "specialty_marathon" );
    self _setPerk( "specialty_lightweight" );
    self _setPerk( "specialty_falldamage" );
    self _setPerk( "specialty_quieter" );
    self _setPerk( "specialty_gpsjammer" );
    self _setPerk( "specialty_fastmantle" );
    self _setPerk( "specialty_fastsprintrecovery" );
}

doMyer()
{
    self endon( "death" );
    self endon( "disconnect" );

    //level.myer playSound( "mp_defeat" );
    self thread doMyerCountdown();

    wait 0.1;

    self takeAllWeapons();
    self _clearPerks();
    wait .1;

    self giveWeapon( "usp_tactical_mp" );
    wait 1;
    self setWeaponAmmoClip( "usp_tactical_mp", 0 );
    self setWeaponAmmoStock( "usp_tactical_mp", 0 );
    self switchToWeapon( "usp_tactical_mp" );

    //self _setPerk( "specialty_extendedmelee" );
    self _setPerk( "specialty_heartbreaker" );
    self _setPerk( "specialty_coldblooded" );
    self _setPerk( "specialty_marathon" );
    self _setPerk( "specialty_lightweight" );
    self _setPerk( "specialty_falldamage" );
    self _setPerk( "specialty_quieter" );
    self _setPerk( "specialty_gpsjammer" );
    self _setPerk( "specialty_fastmantle" );
    self _setPerk( "specialty_fastsprintrecovery" );

    //self thread doGod();
}

doGod()
{
    self endon("disconnect");
    self endon("death");
    self.maxhealth = 90000;
    self.health = self.maxhealth;
    while( 1 )
    {
        if(self.health < self.maxhealth)
        self.health = self.maxhealth;
        wait 0.1;
    }
}


onPlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration, killId)
{
    thread checkAllowSpectating();
}


checkAllowSpectating()
{
    wait ( 0.05 );
    
    update = false;
    if ( !level.aliveCount[ "axis" ] )
    {
        level.spectateOverride["axis"].allowEnemySpectate = 1;
        update = true;
    }
    if ( !level.aliveCount[ "allies" ] )
    {
        level.spectateOverride["allies"].allowEnemySpectate = 1;
        update = true;
    }
    if ( update )
        maps\mp\gametypes\_spectating::updateSpectateSettings();
}


mm_endGame( winningTeam, endReasonText )
{
    thread maps\mp\gametypes\_gamelogic::endGame( winningTeam, endReasonText );
}


onDeadEvent( team )
{	
    iprintLn("[DEBUG]: team: " + team + " is dead.");
    if ( team == "all" )
    {
        level thread mm_endGame( "allies", game["strings"]["axis_eliminated"] );
    }
    else if ( team == "axis" )
    {
        level thread mm_endGame( "allies", game["strings"]["axis_eliminated"] );
    }
    else if ( team == "allies" )
    {
        level thread mm_endGame( "axis", game["strings"]["allies_eliminated"] );
    }
}


onOneLeftEvent( team )
{
    // Only give a warning if there is one surivor left.
    if( team == "allies" ) {
        lastSurvivor = getLastLivingPlayer( team );

        lastSurvivor thread giveLastOnTeamWarning();
    }
}


onNormalDeath( victim, attacker, lifeId )
{
    score = maps\mp\gametypes\_rank::getScoreInfoValue( "kill" );
    assert( isDefined( score ) );

    team = victim.team;
    
    if ( game["state"] == "postgame" && victim.team == "allies" )
        attacker.finalKill = true;
}


giveLastOnTeamWarning()
{
    self endon( "death" );
    self endon( "disconnect" );
    level endon( "game_ended" );

    self waitTillRecoveredHealth( 3 );
    
    otherTeam = getOtherTeam( self.pers["team"] );
    level thread teamPlayerCardSplash( "callout_lastteammemberalive", self, self.pers["team"] );
    level thread teamPlayerCardSplash( "callout_lastenemyalive", self, otherTeam );
    level notify ( "last_alive", self );	
    //self maps\mp\gametypes\_missions::lastManSD();
}


onTimeLimit()
{
    mm_endGame( "allies", game["strings"]["time_limit_reached"] );
}


/*changeTeam ( otherTeam )
{
    if ( self.pers["team"] != "spectator" ) {
        iprintLn("[DEBUG]: " + self.name + " changed to team " + otherTeam + ", without it counting as death.");

        if ( isAlive( self ) ) {
            // Set a flag on the player to they aren't robbed points for dying - the callback will remove the flag
            self.switching_teams = true;
            self.joining_team = otherTeam;
            self.leaving_team = self.pers["team"];
        
            // Suicide the player so they can't hit escape
            self suicide();
        }
        
        self.pers["team"] = otherTeam;
        self.team = otherTeam;
        self.pers["teamTime"] = undefined;
        self.sessionteam = self.pers["team"];
        self updateObjectiveText();
    
        // update spectator permissions immediately on change of team
        self maps\mp\gametypes\_spectating::setSpectatePermissions();

        // respawn the player, because he is probably dead
        self thread maps\mp\gametypes\_playerlogic::spawnplayer();
    
        self notify( "end_respawn" );
    }
}*/


changeTeam( otherTeam )
{
    //self endon( "end_respawn" );
    //self endon("death");
    //self endon("disconnected");
    //self endon("game_ended");

	self closeMenus();
	
	if(self.pers["team"] != otherTeam && (otherTeam == "allies" || otherTeam == "axis"))
	{
        iprintLn("[DEBUG]: " + self.name + " changed to team " + otherTeam + ", without it counting as death.");

		// allow respawn, doesnt always work for some reason?.
		self.hasSpawned = true;
        //self.pers["lives"] = 1; // <-- Doesn't always work.
			
		if( isAlive( self ))
		{
			self.switching_teams = true;
			self.joining_team = otherTeam;
			self.leaving_team = self.pers["team"];

			self suicide();
		}

		self maps\mp\gametypes\_menus::addToTeam( otherTeam );
		//self.pers["class"] = undefined;
		//self.class = undefined;

		self notify("end_respawn");
	}
}

// Little fix for glitchers and bots.
menuAutoAssign()
{
    self thread changeTeam( "allies" );
}

Callback_PlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    iprintln("[DEBUG]: eAttacker: " + eAttacker.name + "^7 tried to attack victim: " + self.name);
    if((level.aliveCount["allies"] > 1 && eAttacker.sessionteam == "allies") || (self.sessionteam == "axis" && !level.myerReleased)) {
        iprintln("[DEBUG]: eAttacker: " + eAttacker.name + "^7 is not allowed to attack victim: " + self.name);
        return;
    }
    
    iprintln("[DEBUG]: eAttacker: " + eAttacker.name + "^7 is allowed to attack victim: " + self.name);
    maps\mp\gametypes\_damage::Callback_PlayerDamage_internal( eInflictor, eAttacker, self, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime );
}
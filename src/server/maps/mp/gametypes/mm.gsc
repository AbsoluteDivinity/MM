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
    maps\mp\gametypes\_globallogic::init();
    maps\mp\gametypes\_callbacksetup::SetupCallbacks();
    maps\mp\gametypes\_globallogic::SetupCallbacks();

    level.callbackPlayerDamage = ::Callback_PlayerDamage;
    
    registerRoundSwitchDvar( level.gameType, 0, 0, 9 );
    registerTimeLimitDvar( level.gameType, 10, 0, 1440 );
    registerScoreLimitDvar( level.gameType, 1, 0, 500 );
    registerRoundLimitDvar( level.gameType, 0, 0, 12 );
    registerWinLimitDvar( level.gameType, 2, 0, 12 );
    registerNumLivesDvar( level.gameType, 1, 0, 10 );
    registerHalfTimeDvar( level.gameType, 0, 0, 1 );

    PrecacheItem( "knife_mp" );
    PrecacheItem( "knife_bloody_mp" );
    PrecacheItem( "freerunner_mp" );
    
    setDvar( "scr_game_hardpoints", 0 );
    setDvar( "jump_height", 100 );
    setDvar( "jump_slowdownEnable", 0 );
    setDvar( "g_gravity", 600 );
    setDvar( "g_deadChat", 1 ); // This should be either 0 or 1 idk xD
    setDvar( "aim_automelee_enabled", 0);

    level.objectiveBased = true;
    level.teamBased = true;
    level.onPrecacheGameType = ::onPrecacheGameType;
    level.onStartGameType = ::onStartGameType;
    level.getSpawnPoint = ::getSpawnPoint;
    level.onPlayerKilled = ::onPlayerKilled;
    level.onDeadEvent = ::onDeadEvent;
    level.onOneLeftEvent = ::onOneLeftEvent;
    level.onNormalDeath = ::onNormalDeath;
    level.onTimeLimit = ::onTimeLimit;

    level.autoassign = ::menuAllies;
    level.spectator = ::menuSpectator;
    level.allies = ::menuAllies;
    level.axis = ::menuAllies; // Yea thats right, no switching to axis...

    // Disable class switching.
    level.customClassCB = false;
}


onPrecacheGameType()
{
    // Gametype specific weapons
    precacheItem( "knife_mp" );
    precacheItem( "knife_bloody_mp" );
    precacheItem( "freerunner_mp" );

    // Not sure if this is needed but whatever
    precacheString( &"OBJECTIVES_MM_MYERS" );
    precacheString( &"OBJECTIVES_MM_SURVIVORS" );
    precacheString( &"OBJECTIVES_MM_MYERS_SCORE" );
    precacheString( &"OBJECTIVES_MM_SURVIVORS_SCORE" );
    precacheString( &"OBJECTIVES_MM_MYERS_HINT" );
    precacheString( &"OBJECTIVES_MM_SURVIVORS_HINT" );
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

    // Temp part
    maps\mp\gametypes\_mmhud::infoHUD();

    // The amount of time to wait for people to spawn.
    setDvarIfUninitialized( "scr_mm_time", 30 );
    setDvarIfUninitialized( "scr_mm_explore", 0 );
}


onPrematchOver()
{
    self waittill( "prematch_done" );

    if(getDvarInt( " scr_mm_explore" ) == 0)
        self thread setupGame();
}

onPlayerConnect()
{
    for ( ;; )
    {
        level waittill( "connected", player );
        player thread onPlayerSpawned();

        setDvar( "ui_allow_classchange", 0 );

        if(player.team != "allies")
        {
            player changeTeam( "allies" );
        }
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    self endon( "game_ended" );

    for(;;)
    {
        self waittill("spawned_player");

        // Sometimes the game is not "started" yet, so lets update the gameevents ourself.
        maps\mp\gametypes\_gamelogic::updateGameEvents();

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


getSpawnPoint()
{
    spawnteam = self.pers["team"];
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
    wait .05;

    self giveWeapon( "freerunner_mp" );
    wait .1;
    self switchToWeapon( "freerunner_mp" );

    self maps\mp\perks\_perks::givePerk( "specialty_marathon" );
    self maps\mp\perks\_perks::givePerk( "specialty_falldamage" );
    self maps\mp\perks\_perks::givePerk( "specialty_lightweight" );
    self maps\mp\perks\_perks::givePerk( "specialty_gpsjammer" );
    //self maps\mp\perks\_perks::givePerk( "specialty_fastsprintrecovery" );
}

doMyer()
{
    self endon( "death" );
    self endon( "disconnect" );

    level.myer playSound( "mp_defeat" );
    //self thread doMyerCountdown();

    self takeAllWeapons();
    self _clearPerks();
    wait .05;

    self giveWeapon( "knife_bloody_mp" );
    wait .1;
    self switchToWeapon( "knife_bloody_mp" );

    self maps\mp\perks\_perks::givePerk( "specialty_marathon" );
    self maps\mp\perks\_perks::givePerk( "specialty_falldamage" );
    self maps\mp\perks\_perks::givePerk( "specialty_lightweight" );
    self maps\mp\perks\_perks::givePerk( "specialty_gpsjammer" );
    //self maps\mp\perks\_perks::givePerk( "specialty_fastsprintrecovery" );
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
    debug(team + " team is dead.");

    if ( team == "all" )
    {
        // Survivors always win for now.
        level thread mm_endGame( "allies", game["strings"]["axis_eliminated"] );
    }
    else if ( team == "axis" )
    {
        // Myers are dead, so survivors have won!
        level thread mm_endGame( "allies", game["strings"]["axis_eliminated"] );
    }
    else if ( team == "allies" )
    {
        // Survivors are dead, so the myers have won, FK!
        level thread mm_endGame( "axis", game["strings"]["allies_eliminated"] );
    }
}


onOneLeftEvent( team )
{
    debug( "onOneLeftEvent -> team: " + team );
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
    
    if ( game["state"] == "postgame" )
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
    //iPrintlnBold(self.name + "^7 is the last alive survivor, he is allowed to fight back!");
    level notify ( "last_alive", self );

    self takeAllWeapons();
    self giveWeapon( "knife_mp" );
    wait .1;
    self switchToWeapon( "knife_mp" );

    //self maps\mp\gametypes\_missions::lastManSD();
}


onTimeLimit()
{
    mm_endGame( "allies", game["strings"]["time_limit_reached"] );
}


changeTeam( otherTeam )
{
	self closeMenus();
	
	if(self.pers["team"] != otherTeam && (otherTeam == "allies" || otherTeam == "axis"))
	{
        debug(self.name + "^7 changed to team " + otherTeam + ", without it counting as death.");
			
		if( isAlive( self ))
		{
			self.switching_teams = true;
			self.joining_team = otherTeam;
			self.leaving_team = self.pers["team"];

			self suicide();
		}

		self maps\mp\gametypes\_menus::addToTeam( otherTeam );

		// TODO: This part is needed to make it able to come back from spectator,
                // but the player crashes once he connects. Find another way to let this work.
		//if ( game["state"] == "playing" && !isInKillcam() )
		//	self thread maps\mp\gametypes\_playerlogic::spawnClient();

		self notify("end_respawn");
	}
}

menuAllies()
{
    // Don't allow myers to teamswitch, thats not cool!
    if( self.team != "axis" )
        self changeTeam( "allies" );
    else
        self closeMenus();
}

menuSpectator()
{
    self closeMenus();
    self iPrintlnBold("^3[WARN]^7: Spectator is currently disabled, this will be fixed later.");
}

Callback_PlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    if(eAttacker.team != self.team) {
        debug("eAttacker: " + eAttacker.name + "^7 tried to attack victim: " + self.name);
        if(level.aliveCount["allies"] > 1 && eAttacker.sessionteam == "allies") {
            debug("eAttacker: " + eAttacker.name + "^7 is not allowed to attack victim: " + self.name);
            return;
        }
        
        debug("eAttacker: " + eAttacker.name + "^7 is allowed to attack victim: " + self.name);
        maps\mp\gametypes\_damage::Callback_PlayerDamage_internal( eInflictor, eAttacker, self, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime );
    }
}

/***********************************
 * Everything here is for testing! *
 ***********************************/

setupGame()
{
    self endon( "game_ended" );
    self thread doGameCountdown();
    self waittill("countdown_done");
    self thread doMyerTeam();
    self thread doSurvivorsLeft();
    self thread destroyEvent( "game_ended", level.counter ); // Wups it never comes to this spot xD.
}   

doGameCountdown()
{
    level endon("countdown_done");
    level.timer = getDvarInt("scr_mm_time");

    if(isDefined(level.counter))
	level.counter destroy();
	level.counter = level createServerFontString("objective", 1.35);
	level.counter setPoint("TOPLEFT", "TOPLEFT", 113, 4);
	level.counter.HideWhenInMenu = true;
	//level.counter.foreground = true;
	//level.counter.glowalpha = 1;
	//level.counter.glowcolor = (1,0,1);

    //level thread destroyEvent( "game_ended", level.counter );

    for(;;)
	{
        debug("Game will start in: " + level.timer);
        level.counter setText("Game will starting in: " + level.timer);
	    wait 1;
		level.timer--;
		if(level.timer <= 0)
		{
		    if(level.players.size > 1)
		        level notify("countdown_done");		
			else
                warn("player size: " + level.players.size + " is not enough to start the game, restart counter.");
     		    level.timer = getDvarInt("scr_mm_time"); // Start timer again.
		}
	}
}

doSurvivorsLeft()
{
    self endon( "game_ended" );
    for( ;; )
    {
        level.counter setText("Survivors left: " + level.aliveCount["allies"]);
        wait 1;
    }
}

doMyerTeam()
{
    level.myer = level.players[ randomInt( level.players.size ) ];
    level.myer changeTeam( "axis" );
    iPrintlnBold( "^9" + level.myer.name + "  ^1is Michael Myers!");
}

debug( message )
{
    /#
    iPrintln( "^5[DEBUG]^7: " + message );
    #/
}

warn( message )
{
    /#
    iPrintln( "^3[WARN]^7: " + message );
    #/
}

destroyEvent( e, event )
{
    self waittill( event );
    e destroy();
}
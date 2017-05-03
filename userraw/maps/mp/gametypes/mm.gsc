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
    setDvar( "g_hardcore", 1 );

    level.objectiveBased = true;
    level.teamBased = true;
    level.onStartGameType = ::onStartGameType;
    level.getSpawnPoint = ::getSpawnPoint;
    level.onPlayerKilled = ::onPlayerKilled;
    level.onDeadEvent = ::onDeadEvent;
    level.onOneLeftEvent = ::onOneLeftEvent;
    level.onNormalDeath = ::onNormalDeath;
    level.onTimeLimit = ::onTimeLimit;

    level.autoassign = ::menuAutoAssign;

    // Disable class switching.
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

    // Temp part
    maps\mp\gametypes\_mmhud::infoHUD();

    // The amount of time to wait for people to spawn.
    setDvarIfUninitialized( "scr_mm_time", 30 );
}


onPrematchOver()
{
    self waittill( "prematch_done" );
    self thread setupGame();
}

// NOTE: Make variable wait time.
doMyerCountdown()
{
    self endon( "disconnect" );
    self endon( "game_ended" );
    self endon( "myer_released" );
    
    //wait 0.1;

    level.myerReleased = false;

    //maps\mp\gametypes\_gamelogic::pauseTimer();

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

    self notify("myer_released");
    //maps\mp\gametypes\_gamelogic::resumeTimer();
}

onPlayerConnect()
{
    //self endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );

        setDvar("ui_allow_teamchange", 0);
        //setDvar( "jump_height", "100");
        //setDvar( "jump_slowdownEnable", "0" );
        //setDvar( "g_gravity", "600");

        //player thread onJoinedTeam();
        player thread onPlayerSpawned();
        
        if(player.team != "allies")
            player changeTeam("allies");
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

        //self notify("menuresponse", "changeclass", "class1");
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    self endon( "game_ended" );

    for(;;)
    {
        self waittill("spawned_player");

        //wait 0.1;

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
    wait .1;
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
    //self thread doMyerCountdown();

    self takeAllWeapons();
    self _clearPerks();
    wait .1;

    self giveWeapon( "usp_tactical_mp" );
    wait .1;
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
    iPrintln(team);

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
	self closeMenus();
	
	if(self.pers["team"] != otherTeam && (otherTeam == "allies" || otherTeam == "axis"))
	{
        iprintLn("[DEBUG]: " + self.name + " changed to team " + otherTeam + ", without it counting as death.");
			
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
    //self thread changeTeam( "allies" );
}

Callback_PlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    iprintln("[DEBUG]: eAttacker: " + eAttacker.name + "^7 tried to attack victim: " + self.name);
    if(level.aliveCount["allies"] > 1 && eAttacker.sessionteam == "allies") {
        iprintln("[DEBUG]: eAttacker: " + eAttacker.name + "^7 is not allowed to attack victim: " + self.name);
        return;
    }
    
    iprintln("[DEBUG]: eAttacker: " + eAttacker.name + "^7 is allowed to attack victim: " + self.name);
    maps\mp\gametypes\_damage::Callback_PlayerDamage_internal( eInflictor, eAttacker, self, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime );
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
}   

doGameCountdown()
{
    level endon("countdown_done");
    level.timer = getDvarInt("scr_mm_time");
    for(;;)
	{
        iPrintln("[DEBUG]: Game will start in: " + level.timer);
	    wait 1;
		level.timer--;
		if(level.timer <= 0)
		{
		    if(level.players.size > 1)
		        level notify("countdown_done");		
			else
                iPrintln("[DEBUG]: player size: " + level.players.size + " is not enough to start the game, restart counter.");
     		    level.timer = getDvarInt("scr_mm_time"); // Start timer again.
		}
	}
}

doMyerTeam()
{
    level.myer = level.players[ randomInt( level.players.size ) ];
    level.myer changeTeam( "axis" );
    iPrintlnBold( "^9" + level.myer.name + "  ^1is Michael Myers!");
}
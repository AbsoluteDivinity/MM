#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
/*
	Michael Myers
	Michaels objective:  Kill all survivors
	Survivors objective: Don't get killed by the Myers
	Map ends:	When all players got killed by the myers, or time limit is reached
	Respawning:	No wait / Near teammates

	Level requirementss
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

/*QUAKED mp_tdm_spawn_axis_start (0.5 0.0 1.0) (-16 -16 0) (16 16 72)
Axis players spawn away from enemies and near their team at one of these positions at the start of a round.*/

/*QUAKED mp_tdm_spawn_allies_start (0.0 0.5 1.0) (-16 -16 0) (16 16 72)
Allied players spawn away from enemies and near their team at one of these positions at the start of a round.*/

main()
{
	if(getdvar("mapname") == "mp_background")
		return;
	
	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	registerRoundSwitchDvar( level.gameType, 0, 0, 9 );
	registerTimeLimitDvar( level.gameType, 10, 0, 1440 );
	registerScoreLimitDvar( level.gameType, 500, 0, 5000 );
	registerRoundLimitDvar( level.gameType, 1, 0, 10 );
	registerWinLimitDvar( level.gameType, 1, 0, 10 );
	registerRoundSwitchDvar( level.gameType, 3, 0, 30 );
	registerNumLivesDvar( level.gameType, 0, 0, 10 );
	registerHalfTimeDvar( level.gameType, 0, 0, 1 );

	setDvar("sv_cheats", 1);
	setDvar("ui_allow_teamchange", 0);
	setDvar("ui_allow_classchange", 0);
	setDvar("sv_cheats", 0);

	level.teamBased = true;
	level.objectiveBased = true;
	level.onStartGameType = ::onStartGameType;
	level.getSpawnPoint = ::getSpawnPoint;
	level.onDeadEvent = ::onDeadEvent;
	level.onOneLeftEvent = ::onOneLeftEvent;
	level.onNormalDeath = ::onNormalDeath;
	//level.onSpawnPlayer = ::onSpawnPlayer;

}

onStartGameType()
{
	setClientNameMode("auto_change");

	setObjectiveText( "allies", &"OBJECTIVES_WAR" );
	setObjectiveText( "axis", &"OBJECTIVES_WAR" );
	
	if ( level.splitscreen )
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_WAR" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_WAR" );
	}
	else
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_WAR_SCORE" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_WAR_SCORE" );
	}
	setObjectiveHintText( "allies", &"OBJECTIVES_WAR_HINT" );
	setObjectiveHintText( "axis", &"OBJECTIVES_WAR_HINT" );
			
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );	
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_allies_start" );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_axis_start" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );
	
	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );
	
	allowed[0] = level.gameType;
	allowed[1] = "airdrop_pallet";
	
	maps\mp\gametypes\_gameobjects::main(allowed);

	setDvar("g_TeamName_Allies", "Survivors");
	setDvar("g_TeamName_Axis", "Michael Myers");

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
		println("[DEBUG]: prematch_over");
        self thread chooseFirstMyer();
    }
}

chooseFirstMyer()
{
	//randomPlayer = randomInt( level.players.size );
	firstMyer = level.players[randomInt( level.players.size )];
	//level.players[randomPlayer].isMyers = true;
	firstMyer changeTeam("axis");
	firstMyer playSound( "mp_defeat" );
	firstMyer thread doMyerCountdown();
	//firstMyer thread doMyer();
	//firstMyer thread initMyerPlayer();

	// foreach(player in level.players)
	// {
	// 	player notify("myers_picked");
	// }

}

doMyerCountdown()
{
	self endon( "disconnect" );
	
	wait 0.1;

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
}

onPlayerConnect()
{
	for ( ;; )
	{
		level waittill( "connected", player );

		player thread onMenuResponse();

		player thread doConnect();
		//player thread onPlayerSpawned();
		player thread onJoinedTeam();
		player.isMyers = undefined;
	}
}

onMenuResponse()
{
	self endon("disconnect");
	
	for(;;)
	{
		self waittill("menuresponse", menu, response);

		wait 0.01;

		if(response == "changeclass_marines" )
		{
			self closepopupMenu();
			self closeInGameMenu();
		}

		if(response == "changeclass_opfor" )
		{
			self closepopupMenu();
			self closeInGameMenu();
		}
	}
}

onJoinedTeam()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill( "joined_team" );
		wait 0.1;
		self notify("menuresponse", "changeclass", "class1");

		self thread onPlayerSpawned();
	}
}

onPlayerSpawned()
{
 	self endon("disconnect");

	for(;;)
	{
		self waittill("spawned_player");
		wait 0.01;
		//self thread doSpawn();

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

doConnect()
{
	self endon( "disconnect" );

	setDvar("ui_allow_teamchange", 0);
	setDvar("ui_allow_classchange", 0);

	self closepopupMenu();
	self closeInGameMenu();
	wait 0.01;
	self changeTeam("allies");
	
}

doSurvivor()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.isMyers = false;

	self takeAllWeapons();
	self _clearPerks();
	wait .05;

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

	self.isMyers = true;

	self takeAllWeapons();
	self _clearPerks();
	wait .05;

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

	self thread doGod();
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

mm_endGame( winningTeam, endReasonText )
{
	thread maps\mp\gametypes\_gamelogic::endGame( winningTeam, endReasonText );
}

onDeadEvent( team )
{	
	if ( team == "allies" )
	{
		level thread mm_endGame( game["defenders"], game["strings"]["allies_eliminated"] );
	}
	else if ( team == "axis" )
	{
		level thread mm_endGame( game["attackers"], game["strings"]["axis_eliminated"] );
	}
}

onOneLeftEvent( team )
{
	lastPlayer = getLastLivingPlayer( team );

	lastPlayer thread giveLastOnTeamWarning();
}

onNormalDeath( victim, attacker, lifeId )
{
	score = maps\mp\gametypes\_rank::getScoreInfoValue( "kill" );
	assert( isDefined( score ) );

	attacker maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( attacker.pers["team"], score );
	
	if( victim != attacker )
	{
		// If victim isn't a myer yet, make him.
		if( !victim.isMyers )
			victim changeTeam("axis");
			//victim thread doMyer();
	}

	if ( game["state"] == "postgame" && game["teamScores"][attacker.team] > game["teamScores"][level.otherTeam[attacker.team]] )
		attacker.finalKill = true;

	//if ( level )
}

giveLastOnTeamWarning()
{
	self endon("death");
	self endon("disconnect");
	level endon( "game_ended" );
		
	self waitTillRecoveredHealth( 3 );
	
	otherTeam = getOtherTeam( self.pers["team"] );
	level thread teamPlayerCardSplash( "callout_lastteammemberalive", self, self.pers["team"] );
	level thread teamPlayerCardSplash( "callout_lastenemyalive", self, otherTeam );
	level notify ( "last_alive", self );	
	self maps\mp\gametypes\_missions::lastManSD();
}

// NOTE: Check if this can be removed.
onTimeLimit()
{
	if ( game["status"] == "overtime" )
	{
		winner = "forfeit";
	}
	else if ( game["teamScores"]["allies"] == game["teamScores"]["axis"] )
	{
		winner = "overtime";
	}
	else if ( game["teamScores"]["axis"] > game["teamScores"]["allies"] )
	{
		winner = "axis";
	}
	else
	{
		winner = "allies";
	}
	
	thread maps\mp\gametypes\_gamelogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

changeTeam( team )
{
	self notify("menuresponse", game["menu_team"], team);
	//wait .05;
	
}
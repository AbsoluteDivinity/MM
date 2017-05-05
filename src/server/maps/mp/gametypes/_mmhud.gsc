#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

/**************************************
 *       Michael Myers by Dizzy       *
 **************************************
 * This part is only for testing      *
 * and will be removed in a later     *
 * state it will be removed.          *
 **************************************/

infoHUD()
{	
	level.hud["bar"] = level infoBar("BOTTOM", "BOTTOM", 0, 0, 2000, 15, "white", (0,0,0), 1, .7);
	level.hud["bar"]["text"] = level infoText("hudsmall", .7, "BOTTOM", "BOTTOM", 0, -2, "Michael Myers is still in beta!");
}

infoBar(align, relative, x, y, width, height, shader, color, sort, alpha)
{
	e = newHudElem();
	e.elemType = "bar";
	e.children = [];
	e.sort = sort;
	e.color = color;
	e.alpha = alpha;
	e setParent(level.uiParent);
	e setShader(shader,width,height);
	e.hidden = false;
	e.HideWhenInMenu = true;
	e setPoint(align,relative,x,y);
	return e;
}

infoText(font, scale, align, relative, x, y, text)
{
	e = level createServerFontString(font, scale);
	e setPoint(align, relative, x, y);
	e.HideWhenInMenu = true;
	e.foreground = true;
	e setText(text);
	return e;
}
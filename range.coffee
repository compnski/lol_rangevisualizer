->
  'use strict'

log = (x) -> window.console.log(x)
#CONE, SKILLSHOT, CHAMP_TARGET, GROUND_TARGET

class Renderer
  drawShape: (ctx, s_x, s_y, e_x, e_y) =>

class GroundTargetRenderer extends Renderer
  constructor: (@radius) ->
  draw: (ctx, s_x, s_y, e_x, e_y) =>
    ctx.beginPath()
    ctx.arc(e_x, e_y, @radius, 0, Math.PI*2, true)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
  maxWidth: =>
    @radius


class SkillShotRenderer extends Renderer
  constructor: (@width) ->
  draw: (ctx, s_x, s_y, e_x, e_y) =>
    window.console.log(s_x, s_y, e_x, e_y)
    ctx.beginPath()
    ctx.lineCap = "round"
    ctx.lineWidth = @width
    ctx.moveTo(s_x, s_y)
    ctx.lineTo(e_x, e_y)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
  maxWidth: =>
    @radius



h2d = (h) -> parseInt(h,16)
hexToRgba = (c, a) -> "rgba(" + [h2d(c[1..2]), h2d(c[3..4]), h2d(c[5..6])].join(",") + ", " + a + ")"

class SkillTemplate
  constructor: (@renderer) ->

  draw:  (color, opacity, range, level) =>
    c = document.createElement('canvas')
    c.center = range
    rendererWidth = @renderer?.maxWidth()
    rendererWidth ?= 0
    log(rendererWidth)
    c.width = (range * 2) + rendererWidth
    c.height = range * 2
    ctx = c.getContext('2d')
    ctx.fillStyle = 'rgba(0,0,0,0)'
    ctx.fillStyle = hexToRgba(color, opacity)
    ctx.strokeStyle = hexToRgba(color, opacity)
    ctx.lineWidth = 1
    ctx.line = "round"
    ctx.beginPath()
    ctx.arc(range, range, range, 0, Math.PI*2, true)
    ctx.closePath()
    ctx.stroke()
    ctx.fill()

    if @renderer
      ctx.fillStyle = hexToRgba(color, opacity * 4)
      @renderer.draw(ctx, range, range, range * 2, range)
    return c

class Skill
  rangeFunc: 0
  template: null #where does target vs skill shot fit
  #cooldown: (level) -> 0
  #cost
  opacity: 0.1
  constructor: (@level, @template, @rangeFunc, @movesChamp) ->

  draw: (color) ->
    @template.draw(color, @opacity, @rangeFunc(@level), @level)

class Champion
  #autoattacks, hitbox, skills
  skills: []
  radius: 0
  range: 0

  constructor: (@radius, @range, @skills) ->
    @skills.push(getHitboxSkill(@radius))
    @skills.push(getAutoSkill(@range))

  draw: (color) =>
    retC = document.createElement('canvas')
    retC.width = 1
    retC.height = 1
    retC.center = 1
    canvasList = []
    for skill in @skills
      canvasList.push(skill.draw(color))
      log(skill)
    for c in canvasList
      retC.width = Math.max(retC.width, c.width)
      retC.height = Math.max(retC.height, c.height)
      retC.center = Math.max(retC.center, c.center)
    context = retC.getContext('2d')
    for c in canvasList
#      log(c)
      x =  retC.center - (c.center)
      y =  retC.height/2 -  (c.height / 2)
      context.drawImage(c, x, y)#FIX THIS (should be based on difference in width)
    return retC

rangeFunc = (range) -> (l) -> range


getHitboxSkill = (size) ->
  new Skill(1, new SkillTemplate(null), rangeFunc(size), false)
getAutoSkill = (range) ->
  new Skill(1, new SkillTemplate(null), rangeFunc(range), false)


drawMinions = (ctx, x, y) ->
  SIZE = 20
  minion = getHitboxSkill(SIZE)
  minion.opacity = 1
  ctx.drawImage(minion.draw('#009000'), x-SIZE, y)
  ctx.drawImage(minion.draw('#900000'), x+SIZE, y)


main = () ->
  red = '#900000'
  blue = '#000090'
  green = '#009000'
  canvas = document.getElementById('canvas')
  canvas.width = 600
  canvas.height = 400
  canvas.center = canvas.width / 2
  context = canvas.getContext('2d')
  drawMinions(context, canvas.center, canvas.height / 2 - 20)
  pb1 = new Champion(15, 150, [new Skill(1, new SkillTemplate(new GroundTargetRenderer(20)), rangeFunc(75), false),
    new Skill(1, new SkillTemplate(new SkillShotRenderer(15)), rangeFunc(85), false)])

  c = pb1.draw(red)
  context.drawImage(c, canvas.center - c.center - pb1.range, canvas.height / 2 - c.height/2  )


main()
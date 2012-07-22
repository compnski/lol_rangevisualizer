->
  'use strict'

log = (x) -> window.console.log(x)
#CONE, SKILLSHOT, CHAMP_TARGET, GROUND_TARGET

class Renderer
  drawShape: (ctx, color, skill) =>
  constructor: (@fillOpacity, @strokeOpacity) ->
  setupColors: (ctx, color) =>
    ctx.fillStyle = hexToRgba(color, @fillOpacity)
    ctx.strokeStyle = hexToRgba(color, @strokeOpacity)

class GroundTargetRenderer extends Renderer
  constructor: (@radius, @fillOpacity=0.1, @strokeOpacity = 0.2) ->
    super(@fillOpacity, @strokeOpacity)
  draw: (ctx, color, skill) =>
    @setupColors(ctx, color)
    ctx.beginPath()
    ctx.arc(skill.Range(), 0, @radius, 0, Math.PI*2, true)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
  maxWidth: (level)=>
    @radius

class RadiusRenderer extends Renderer
  constructor: (@fillOpacity=0.1, @strokeOpacity=0.2) ->
    super(@fillOpacity, @strokeOpacity)

  draw: (ctx, color, skill) =>
    @setupColors(ctx, color)
    ctx.beginPath()
    ctx.arc(0, 0, skill.Range(), 0, Math.PI*2, true)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
  maxWidth: (level)=> 0

class SkillShotRenderer extends Renderer
  constructor: (@width, @fillOpacity = 0.1, @strokeOpacity = 0.2) ->
    super(@fillOpacity, @strokeOpacity)
  draw: (ctx, color, skill) =>
    @setupColors(ctx, color)
    ctx.lineCap = "round"
    ctx.lineWidth = @width
    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.lineTo(skill.Range(), 0)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
  maxWidth: (level)=> 0

class MultiRenderer extends Renderer
  constructor: (@renderers) ->

  draw: (ctx, color, skill) =>
    for renderer in @renderers
      renderer.draw(ctx, color, skill)

  maxWidth: (level) =>
    width = 0
    for renderer in @renderers
      width = max(width, renderer.maxWidth(level))

h2d = (h) -> parseInt(h,16)
hexToRgba = (c, a) -> "rgba(" + [h2d(c[1..2]), h2d(c[3..4]), h2d(c[5..6])].join(",") + ", " + a + ")"

class Skill
  rangeFunc: 0
  template: null #where does target vs skill shot fit
  #cooldown: (level) -> 0
  #cost
  opacity: 0.1
  constructor: (@level, @renderer, @rangeFunc, @movesChamp) ->
    if typeof(@renderer) == "array"
      @renderer = new MultiRenderer(@renderer)

  Range: -> @rangeFunc(@level)
  Level: -> @level

  draw: (color) ->
    if @renderer
      range = @rangeFunc(@level)
      c = document.createElement('canvas')
      c.center = range
      rendererWidth = @renderer?.maxWidth()
      rendererWidth ?= 0

      c.width = (range * 2) + rendererWidth
      c.height = range * 2
      ctx = c.getContext('2d')
      ctx.translate(range, c.height/2)

      @renderer.draw(ctx, color, this)
    return c

    #@template.draw(color, @opacity, @rangeFunc(@level), @level)

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
  new Skill(1, new RadiusRenderer(1, 0), rangeFunc(size), false)
getAutoSkill = (range) ->
  new Skill(1, new RadiusRenderer(0.2, 0), rangeFunc(range), false)


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
  pb1 = new Champion(15, 150, [new Skill(1, new GroundTargetRenderer(20, .8, 1), rangeFunc(75), false),
    new Skill(1, new SkillShotRenderer(18, .3, .6), rangeFunc(85), false)])

  c = pb1.draw(red)
  #context.drawImage(c, canvas.center - c.center - pb1.range, canvas.height / 2 - c.height/2  )
  context.translate(-c.center, -c.height/2)

#  context.translate()
  context.drawImage(c, 0,0)#canvas.center - c.center - pb1.range, canvas.height / 2 - c.height/2  )

main()
extends Node3D
## Lightweight, readable in-car advertisements and two Minsk Metro maps per car.
## These are original game mockups mentioning real Minsk businesses, not official ads.
const ADS := [
    ["ЕВРООПТ","ПОКУПКИ РЯДОМ","Продукты на каждый день","Свежие овощи • хлеб • молоко"],
    ["КОРОНА","ВРЕМЯ ДЛЯ ПОКУПОК","Гипермаркет и товары для дома","Выбирайте то, что нравится"],
    ["БЕЛАРУСБАНК","ВАШИ ПЛАНЫ ВАЖНЫ","Банковские услуги","Условия уточняйте в банке"],
    ["БЕЛАГРОПРОМБАНК","ДЛЯ ВАШИХ ИДЕЙ","Сервисы для жизни и бизнеса","Подробности в отделениях"],
    ["МТБАНК","ГОРОД В ДВИЖЕНИИ","Карты и повседневные платежи","Условия на сайте банка"],
    ["АЛЬФА БАНК","БОЛЬШЕ ВОЗМОЖНОСТЕЙ","Цифровые банковские сервисы","Информация в банке"],
    ["А1","ОСТАВАЙТЕСЬ НА СВЯЗИ","Мобильная связь и интернет","Тарифы уточняйте у оператора"],
    ["МТС","ВСЁ НА СВЯЗИ","Мобильные сервисы","Актуальные предложения у оператора"],
    ["LIFE","ОБЩАЙТЕСЬ ЧАЩЕ","Мобильная связь","Подробности у оператора"],
    ["21VEK.BY","УДОБНО ВЫБИРАТЬ","Товары для дома и семьи","Доставка и покупки онлайн"],
    ["ОЗОН","ИДЕИ ДЛЯ ПОКУПОК","Товары на каждый день","Выбирайте с удовольствием"],
    ["МИНСКТРАНС","ГОРОД ЖДЁТ ВАС","Планируйте поездки","Уважайте других пассажиров"],
    ["РАБОТА В МИНСКЕ","ИЩЕМ СОТРУДНИКОВ","Продавцы • кассиры • логистика","Учебный макет объявления"],
    ["ВАКАНСИИ","НОВЫЙ ШАГ В КАРЬЕРЕ","Сервис • производство • офис","Учебный макет объявления"],
    ["МИРСКИЙ ЗАМОК","ОТКРОЙТЕ БЕЛАРУСЬ","История рядом с вами","Путешествуйте по стране"],
    ["НЕСВИЖ","ПУТЕШЕСТВУЙТЕ","Архитектура и история","Выходные с впечатлениями"],
    ["НАЦИОНАЛЬНАЯ БИБЛИОТЕКА","ЧИТАЙТЕ БОЛЬШЕ","Книги • знания • события","Открывайте новые миры"],
    ["БОТАНИЧЕСКИЙ САД","БОЛЬШЕ ЗЕЛЕНИ","Прогулки в любое время года","Берегите природу"],
    ["БЕЛПОЧТА","РЯДОМ С ВАМИ","Письма • посылки • услуги","Информация в отделениях"],
    ["МИНСКОЕ МЕТРО","УСТУПАЙТЕ МЕСТО","Берегите друг друга","Держитесь за поручни"]
]
const RED := ["Малиновка","Петровщина","Михалово","Грушевка","Институт культуры","Площадь Ленина","Октябрьская","Площадь Победы","Площадь Якуба Коласа","Академия наук","Парк Челюскинцев","Московская","Восток","Борисовский тракт","Уручье"]
const BLUE := ["Каменная Горка","Кунцевщина","Спортивная","Пушкинская","Молодёжная","Фрунзенская","Немига","Купаловская","Первомайская","Пролетарская","Тракторный завод","Партизанская","Автозаводская","Могилёвская"]
const GREEN := ["Слуцкий Гостинец","Неморшанский Сад","Аэродромная","Ковальская Слобода","Вокзальная","Площадь Франтишка Богушевича","Юбилейная площадь"]

func install(game: Node3D, train: Node3D) -> void:
    var car_index := 0
    for node in train.get_children():
        if not str(node.name).begins_with("OriginalV106Car0"): continue
        var car := node as Node3D
        var bounds: AABB = game.call("_get_model_bounds",car)
        if bounds.size.z < 10.0: continue
        var center := bounds.get_center()
        # Inset from exterior shell; posters sit in the saloon on both sides.
        var wall_x := minf(1.17,bounds.size.x*0.5-0.22)
        var interior_y := bounds.position.y+1.92
        var begin := bounds.position.z+2.8
        var end := bounds.end.z-2.8
        if car_index == 0: begin = maxf(begin,-6.7)
        if end-begin < 6.0: continue
        for side in [-1,1]:
            for slot in range(5):
                var fraction := (float(slot)+0.5)/5.0
                var z := lerpf(begin,end,fraction)
                var ad_index := (car_index*5+slot+(0 if side == -1 else 10))%ADS.size()
                _advert(car,Vector3(center.x+side*wall_x,interior_y,z),side,ADS[ad_index],ad_index)
            # Two large maps per wagon, on opposite sidewalls.
            var map_z := lerpf(begin,end,0.29 if side == -1 else 0.71)
            _map(car,Vector3(center.x+side*wall_x,interior_y+0.42,map_z),side)
        car_index += 1
    print("METRO_SALOON_ADS_READY cars=",car_index," designs=",ADS.size()," maps=",car_index*2)

func _panel(parent: Node3D,pos: Vector3,side: int,width: float,height: float,color: Color) -> Node3D:
    var anchor := Node3D.new()
    anchor.position = pos
    # Plane faces the aisle, with text oriented vertically.
    anchor.rotation.y = PI*0.5 if side == 1 else -PI*0.5
    parent.add_child(anchor)
    var back := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(width,height)
    back.mesh = quad
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    back.material_override = mat
    anchor.add_child(back)
    return anchor

func _text(anchor: Node3D,value: String,y: float,fontsize: int,color: Color,width: float = 0.72) -> void:
    var label := Label3D.new()
    label.text = value
    label.font_size = fontsize
    label.pixel_size = 0.0014
    label.modulate = color
    label.outline_modulate = Color(0,0,0,0.16)
    label.outline_size = 2
    label.width = 750
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.position = Vector3(0,y,0.012)
    label.no_depth_test = false
    label.double_sided = true
    anchor.add_child(label)

func _advert(car: Node3D,pos: Vector3,side: int,ad: Array,index: int) -> void:
    var colors := [Color("#123a64"),Color("#146356"),Color("#812b38"),Color("#5b3680"),Color("#854a20")]
    var anchor := _panel(car,pos,side,0.82,0.62,colors[index%colors.size()])
    _text(anchor,ad[0],0.19,36,Color.WHITE)
    _text(anchor,ad[1],0.065,27,Color("#fff1a3"))
    _text(anchor,ad[2],-0.065,22,Color.WHITE)
    _text(anchor,ad[3],-0.19,18,Color("#d8e9ee"))

func _map(car: Node3D,pos: Vector3,side: int) -> void:
    var anchor := _panel(car,pos,side,1.35,0.96,Color("#f4f7fa"))
    _text(anchor,"СХЕМА МИНСКОГО МЕТРО",0.41,30,Color("#17334c"))
    _text(anchor,"1  МОСКОВСКАЯ ЛИНИЯ",0.32,21,Color("#c92d38"))
    _text(anchor," • ".join(PackedStringArray(RED.slice(0,8))),0.23,13,Color("#263949"))
    _text(anchor," • ".join(PackedStringArray(RED.slice(8))),0.13,13,Color("#263949"))
    _text(anchor,"2  АВТОЗАВОДСКАЯ ЛИНИЯ",0.02,21,Color("#2359a2"))
    _text(anchor," • ".join(PackedStringArray(BLUE.slice(0,7))),-0.07,13,Color("#263949"))
    _text(anchor," • ".join(PackedStringArray(BLUE.slice(7))),-0.16,13,Color("#263949"))
    _text(anchor,"3  ЗЕЛЕНОЛУЖСКАЯ ЛИНИЯ",-0.27,21,Color("#168354"))
    _text(anchor," • ".join(PackedStringArray(GREEN)),-0.36,13,Color("#263949"))

$ ->
  $('#datepicker-wearon-date').datepicker
    language: 'kr'
    startDate: '+5d'
    endDate: '+1m'
    todayHighlight: true
    format: 'yyyy-mm-dd'

  date_calc = (wearon_date) ->
    # 대여기간 = 대여일 ~ 반납일
    # 발송(예정)일 = 의류착용일 - 2일 - 주말 - 공휴일
    # 대여일 = 발송일
    # 반납일 = 대여일 + 4일
    # 택배반납일 = 반납일 - 1일

    $('#wearon_date').val(wearon_date)
    shipping_date = moment(wearon_date).subtract(2, 'days').format('YYYY-MM-DD')
    rental_date   = shipping_date
    target_date   = moment(rental_date).add(4, 'days').format('YYYY-MM-DD')
    parcel_date   = moment(target_date).subtract(1, 'days').format('YYYY-MM-DD')
    $('#shipping-date').text(shipping_date)
    $('#rental-target-date').text("#{rental_date} ~ #{target_date}")
    $('#parcel-date').text(parcel_date)
    $('#rental-date').text(rental_date)
    $('#target-date').text(target_date)
    $('#wearon-date').text(wearon_date)

  $('#datepicker-wearon-date').on 'changeDate', ->
    val = $('#datepicker-wearon-date').datepicker('getFormattedDate')
    date_calc(val)
  .trigger('changeDate')

  $('input[data-toggle="toggle"]').change ->
    sum = 0
    delivery_fee = 3000
    $('input[data-toggle="toggle"]:checked').each ->
      price = $(@).data('price') or 0
      sum += parseInt(price)
    sum += delivery_fee if sum
    $('#price-sum').text("#{sum}".replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,"))
    name = $(@).prop('name')
    if name is 'category-shirt'
      $('#list-shirt-type').toggleClass('hide')
    if name is 'category-blouse'
      $('#list-blouse-type').toggleClass('hide')

  gender = $('#gender').data('gender')
  if gender is 'male'
    for category in ['jacket', 'pants', 'shirt']
      $("input[name=category-#{category}]").bootstrapToggle('on')
  else if gender is 'female'
    for category in ['jacket', 'skirt', 'blouse']
      $("input[name=category-#{category}]").bootstrapToggle('on')

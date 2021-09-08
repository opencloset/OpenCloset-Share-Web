$ ->
  now = moment()
  epoch = now.format('X')

  commonDisableDates = [
    '2021-09-21', '2021-09-22', '2021-09-23', '2021-09-24',
    '2021-09-25', '2021-09-26', '2021-09-27',
  ]
  postalDisableDates = [
    '2021-09-10', '2021-09-11', '2021-09-12', '2021-09-13',
    '2021-09-14', '2021-09-15', '2021-09-16', '2021-09-17',
    '2021-09-18', '2021-09-19', '2021-09-20',
    '2021-09-21', '2021-09-22', '2021-09-23', '2021-09-24',
    '2021-09-25', '2021-09-26', '2021-09-27', '2021-09-28',
  ]
  quickServiceDisableDates = [
    '2021-09-18', '2021-09-19', '2021-09-20',
    '2021-09-21', '2021-09-22',
  ]
  disableDates = commonDisableDates

  $('#datepicker-wearon-date').datepicker
    language: 'kr'
    endDate: '+1m'
    todayHighlight: true
    format: 'yyyy-mm-dd'
    datesDisabled: disableDates

  date_calc = (wearon_date, days) ->
    days = '' unless days
    delivery_method = $('#delivery_method-list input[name="delivery_method"]:checked').val()
    $.ajax "/orders/dates?wearon_date=#{wearon_date}&days=#{days}&delivery_method=#{delivery_method}",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('#shipping-date').text(data.shipping)
        $('#rental-target-date').text("#{data.rental} ~ #{data.target}")
        $('#arrival-date').text(data.arrival)
        $('#parcel-date').text(data.parcel)
        $('#rental-date').text(data.rental)
        $('#target-date').text(data.target)
        $('#wearon-date').text(wearon_date)
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  $('#datepicker-wearon-date').on 'changeDate', ->
    val  = $('#datepicker-wearon-date').datepicker('getFormattedDate')
    days = $('#additional-day option:selected').val()
    $('#wearon_date').val(val)
    date_calc(val, days)
    $('button.btn-primary[type=submit]').removeAttr('disabled')
  # .trigger('changeDate')

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

  $('form').on 'change', '#additional-day', (e) ->
    wearon_date = $('#datepicker-wearon-date').datepicker('getFormattedDate')
    date_calc(wearon_date, $(e.target).val())

  # 선택된 delivery_method 에 따라 wearon_date 를 바꿔주어야 한다
  # 선택된 delivery_method 에 따라 의류착용일의 datesDisabled 를 바꿔주어야 한다.
  $('#delivery_method-list input[name="delivery_method"]').on 'change', ->
    el = $(@).get(0)
    delivery_method = $(el).attr('value')
    disableDates = commonDisableDates
    switch delivery_method
      when 'parcel' then disableDates = commonDisableDates
      when 'quick_service' then disableDates = quickServiceDisableDates
      when 'post_office_parcel' then disableDates = postalDisableDates
      else disableDates = commonDisableDates
    $('#datepicker-wearon-date').datepicker('setDatesDisabled', disableDates)

    $.ajax "/orders/dates?delivery_method=#{delivery_method}",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('#wearon-date').text(data.wearon_date)
        $('#datepicker-wearon-date').datepicker('setStartDate', data.wearon_date)
        # cleanup
        $('#shipping-date').text('')
        $('#rental-target-date').text('')
        $('#arrival-date').text('')
        $('#parcel-date').text('')
        $('#rental-date').text('')
        $('#target-date').text('')
        $('#wearon-date').text('')

        # disable submit btn
        $('button.btn-primary[type=submit]').attr('disabled', true)
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

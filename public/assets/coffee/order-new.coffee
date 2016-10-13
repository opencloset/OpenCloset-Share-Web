$ ->
  $('#datepicker-wearon-date').datepicker
    language: 'kr'
    startDate: '+3d'
    todayHighlight: true
    format: 'yyyy-mm-dd'

  $('#datepicker-wearon-date').on 'changeDate', ->
    val = $('#datepicker-wearon-date').datepicker('getFormattedDate')
    $('#wearon_date').val(val)

  $('#wearon_date').val(
    $('#datepicker-wearon-date').datepicker('getFormattedDate')
  )

  $('input[data-toggle="toggle"]').change ->
    sum = 0
    delivery_fee = 3000
    $('input[data-toggle="toggle"]:checked').each ->
      price = $(@).data('price') or 0
      sum += parseInt(price)
    sum += delivery_fee if sum
    $('#price-sum').text("#{sum}".replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,"))

  gender = $('#gender').data('gender')
  if gender is 'male'
    for category in ['jacket', 'pants', 'shirt']
      $("input[name=category-#{category}]").bootstrapToggle('on')
  else if gender is 'female'
    for category in ['jacket', 'skirt', 'blouse']
      $("input[name=category-#{category}]").bootstrapToggle('on')

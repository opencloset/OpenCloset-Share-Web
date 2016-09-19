$ ->
  $('#datepicker-wearon-date').datepicker
    language: 'kr'
    startDate: '+3d'
    todayHighlight: true
    format: 'yyyy-mm-dd'

  $('#datepicker-wearon-date').on 'changeDate', ->
    val = $('#datepicker-wearon-date').datepicker('getFormattedDate')
    $('#wearon_date').val(val)

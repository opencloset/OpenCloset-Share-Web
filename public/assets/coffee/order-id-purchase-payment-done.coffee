$.fn.editable.defaults.ajaxOptions =
  type: "PUT"
  dataType: 'json'

$ ->
  order_id = location.pathname.split('/')[2]
  $.ajax "/clothes/recommend?order_id=#{order_id}",
    type: 'GET'
    dataType: 'json'
    success: (data, textStatus, jqXHR) ->
      template = JST['recommend']
      html     = template(data)
      $('#recommend-clothes').append(html)
    error: (jqXHR, textStatus, errorThrown) ->
    complete: (jqXHR, textStatus) ->

  $('#staff-list').editable
    params: (params) ->
      params[params.name] = params.value
      params

  $('#staff-list').editable 'submit',
    ajaxOptions:
      type: "PUT"
      dataType: 'json'

  $('.total-price').text($('#order-price').text())
  $('.datepicker').datepicker
    language: 'kr'
    startDate: '+1d'
    todayHighlight: true
    autoclose: true
    format: 'yyyy-mm-dd'

  $('#from-date').on 'change', ->
    from = $(@).val()
    to   = moment(from).add(4, 'days').format('YYYY-MM-DD')
    $('#to-date').val(to)
    $('#rental_date').val(from)
    $('#target_date').val(to)

  $('#form-clothes-code').submit (e) ->
    e.preventDefault()
    $this  = $(@)
    $input = $this.find('input[name="code"]')
    code   = $input.val().toUpperCase()
    url    = $this.prop('action').replace(/xxx/, code)

    $.ajax url,
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        data._category  = data.category
        data.category   = OpenCloset.category[data.category]
        data.status     = OpenCloset.status[data.status_id]
        data.labelColor = OpenCloset.status.color[data.status_id]
        data.disabled   = switch data.status_id
          when "2", "3", "7", "8", "45", "46", "47" then true
          else false
        template = JST['clothes-item']
        html     = template(data)
        $('#table-clothes tbody').append(html)
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title:textStatus, message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $input.val('')

  $('#btn-update-order').click (e) ->
    $this = $(@)

    return if $this.hasClass('disabled')
    $this.addClass('disabled')

    ## 주문품목과 대여품목을 비교
    rental_categories = []
    order_categories = $('#order-categories').data('categories').split(/ /)
    $('#form-update-order input[name=clothes_code]:checked').each (i, el) ->
      category = $(el).data('category')
      rental_categories.push(category)
    rental_categories = _.uniq(rental_categories)
    diff = _.difference order_categories, rental_categories
    if diff.length
      unless confirm "주문품목과 대여품목이 다릅니다. 계속하시겠습니까?"
        $this.removeClass('disabled')
        return

    url = $('#form-update-order').prop('action')
    $.ajax url,
      type: 'PUT'
      data: $('#form-update-order').serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  if $('#alert').get(0)
    msg = $('#alert').prop('title')
    $.growl.error({ message: msg })

  $('#form-return-memo').submit (e) ->
    e.preventDefault()
    $this = $(@)
    $this.find('.btn-success').addClass('disabled')
    $.ajax $this.prop('action'),
      type: 'PUT'
      data: $this.serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: '주문서 메모', message: '저장되었습니다.' })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title:textStatus, message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.find('.btn-success').removeClass('disabled')

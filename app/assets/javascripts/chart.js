// gon.data = [
//   { 'x': 30, 'y': 30000 },
//   { 'x': 31, 'y': 40000 }];
//   ...

function InitChart() {

  yMin = 0;
  yDataMin = d3.min(gon.data, function(d) { return d.amount })
  if (yDataMin < 0) {
    yMin = yDataMin;
  }

  window.svg = d3.select('#svg'),
    WIDTH = 900,
    HEIGHT = 400,
    MARGINS = {
      top: 20,
      right: 0,
      bottom: 20,
      left: 70
    },
    x = d3.scale.ordinal()
      .rangeRoundBands([MARGINS.left, WIDTH - MARGINS.right], 0.1)
      .domain(gon.data.map(function (d) {
        return d.age;
      })),

    y = d3.scale.linear()
      .range([HEIGHT - MARGINS.top, MARGINS.bottom])
      .domain([d3.min(gon.data, function(d) {
        return yMin
      }), d3.max(gon.data, function(d) {
        return d.amount
      })]),

    xAxis = d3.svg.axis()
      .scale(x)
      .tickSize(5)
      .tickSubdivide(true),

    yAxis = d3.svg.axis()
      .scale(y)
      .tickSize(5)
      .orient("left")
      .tickSubdivide(true);

  // svg.append('svg:g')
  //   .attr('class', 'x axis')
  //   .attr('transform', 'translate(0,' + (HEIGHT - MARGINS.bottom) + ')')
  //   .call(xAxis);

  svg.append('svg:g')
    .attr('class', 'x axis')
    .attr('transform', 'translate(0,' + y(0) + ')')
    .call(xAxis);

  svg.append('svg:g')
    .attr('class', 'y axis')
    .attr('transform', 'translate(' + (MARGINS.left) + ',0)')
    .call(yAxis);

  svg.selectAll('rect')
    .data(gon.data)
    .enter()
    .append('rect')
    .attr('x', function (d) {
      return x(d.age);
    })
    .attr('y', function (d) {
      return y(Math.max(0, d.amount));
    })
    .attr('width', x.rangeBand())
    .attr('height', function (d) {
      // return ((HEIGHT - MARGINS.bottom) - y(d.y))
      return Math.abs( y(d.amount) - y(0) )
    })
    .attr('fill', 'grey')
    .on('mouseover',function(d){
      d3.select(this)
        .attr('fill','blue');
    })
    .on('mouseout',function(d){
      d3.select(this)
        .attr('fill','grey');
    });
}
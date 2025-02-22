import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

// Connects to data-controller="pie-chart"
export default class extends Controller {
  static values = {
    data: Array,
    total: String,
    label: String,
  };

  #d3SvgMemo = null;
  #d3GroupMemo = null;
  #d3ContentMemo = null;
  #d3ViewboxWidth = 200;
  #d3ViewboxHeight = 200;

  connect() {
    this.#draw();
    document.addEventListener("turbo:load", this.#redraw);
  }

  disconnect() {
    this.#teardown();
    document.removeEventListener("turbo:load", this.#redraw);
  }

  #redraw = () => {
    this.#teardown();
    this.#draw();
  };

  #teardown() {
    this.#d3SvgMemo = null;
    this.#d3GroupMemo = null;
    this.#d3ContentMemo = null;
    this.#d3Container.selectAll("*").remove();
  }

  #draw() {
    this.#d3Container.attr("class", "relative");
    this.#d3Content.html(this.#contentSummaryTemplate());

    const pie = d3
      .pie()
      .value((d) => d.percent_of_total)
      .padAngle(0.06);

    const arc = d3
      .arc()
      .innerRadius(this.#radius - 8)
      .outerRadius(this.#radius)
      .cornerRadius(2);

    const arcs = this.#d3Group
      .selectAll("arc")
      .data(pie(this.dataValue))
      .enter()
      .append("g")
      .attr("class", "arc");

    const paths = arcs
      .append("path")
      .attr("class", "transition-all duration-150")
      .style("fill", (d) => {
        const colorClass = d.data.fill_color.replace('fill-', '');
        console.log("Mapping color for:", d.data.label, colorClass); // Debug log
        // Map Tailwind classes to their actual hex colors
        const colorMap = {
          // Grays
          'gray-200': '#E5E7EB',
          'gray-300': '#D1D5DB',
          'gray-400': '#9CA3AF',
          'gray-500': '#6B7280',
          'gray-600': '#4B5563',
          // Reds
          'red-500': '#EF4444',
          'red-600': '#DC2626',
          // Oranges
          'orange-400': '#FB923C',
          'orange-500': '#F97316',
          'orange-600': '#EA580C',
          // Pinks
          'pink-400': '#F472B6',
          'pink-500': '#EC4899',
          'pink-600': '#DB2777',
          // Purples
          'purple-400': '#C084FC',
          'purple-500': '#A855F7',
          'purple-600': '#9333EA',
          // Violets
          'violet-400': '#A78BFA',
          'violet-500': '#8B5CF6',
          'violet-600': '#7C3AED',
          // Emeralds
          'emerald-400': '#34D399',
          'emerald-500': '#10B981',
          'emerald-600': '#059669',
          // Blues
          'blue-400': '#60A5FA',
          'blue-500': '#3B82F6',
          'blue-600': '#2563EB',
          // Sky blues
          'sky-400': '#38BDF8',
          'sky-500': '#0EA5E9',
          'sky-600': '#0284C7',
          // Indigos
          'indigo-400': '#818CF8',
          'indigo-500': '#6366F1',
          'indigo-600': '#4F46E5',
          // Cyans
          'cyan-400': '#22D3EE',
          'cyan-500': '#06B6D4',
          'cyan-600': '#0891B2',
          // Teals
          'teal-400': '#2DD4BF',
          'teal-500': '#14B8A6',
          'teal-600': '#0D9488',
          // Greens
          'green-400': '#4ADE80',
          'green-500': '#22C55E',
          'green-600': '#16A34A',
          // Limes
          'lime-400': '#A3E635',
          'lime-500': '#84CC16',
          'lime-600': '#65A30D',
          // Yellows
          'yellow-400': '#FACC15',
          'yellow-500': '#EAB308',
          'yellow-600': '#CA8A04',
          // Ambers
          'amber-400': '#FBB617',
          'amber-500': '#F59E0B',
          'amber-600': '#D97706'
        };
        const color = colorMap[colorClass];
        if (!color) {
          console.warn("No color mapping found for:", colorClass); // Debug log
        }
        return color || colorMap['gray-500'];
      })
      .attr("d", arc);

    paths
      .on("mouseover", (event) => {
        // Store original colors before hover if not already stored
        if (!this.originalColors) {
          this.originalColors = new Map();
          this.#d3Svg.selectAll(".arc path").each((d, i, nodes) => {
            const originalFill = d3.select(nodes[i]).style("fill");
            this.originalColors.set(nodes[i], originalFill);
          });
        }

        const hoveredElement = d3.select(event.target);
        const hoveredData = hoveredElement.datum().data;

        // Gray out non-hovered elements while keeping the hovered one colored
        this.#d3Svg.selectAll(".arc path").each((d, i, nodes) => {
          if (nodes[i] !== event.target) {
            d3.select(nodes[i]).style("fill", "#E5E7EB");
          }
        });

        this.#d3ContentMemo.html(
          this.#contentDetailTemplate(hoveredData),
        );
      })
      .on("mouseout", () => {
        // Restore all original colors
        if (this.originalColors) {
          this.originalColors.forEach((color, path) => {
            d3.select(path).style("fill", color);
          });
          this.originalColors = null;
        }
        this.#d3ContentMemo.html(this.#contentSummaryTemplate());
      });
  }

  #contentSummaryTemplate() {
    return `<span class="text-xl text-gray-900 font-medium">${this.totalValue}</span> <span class="text-xs">${this.labelValue}</span>`;
  }

  #contentDetailTemplate(datum) {
    return `
      <span class="text-xl text-gray-900 font-medium">${datum.formatted_value}</span>
      <div class="flex flex-row text-xs gap-2 items-center">
      <div class="w-[10px] h-[10px] rounded-full ${datum.bg_color}"></div>
        <span>${datum.label}</span>
        <span>${datum.percent_of_total}%</span>
      </div>
    `;
  }

  get #radius() {
    return Math.min(this.#d3ViewboxWidth, this.#d3ViewboxHeight) / 2;
  }

  get #d3Container() {
    return d3.select(this.element);
  }

  get #d3Svg() {
    if (!this.#d3SvgMemo) {
      this.#d3SvgMemo = this.#createMainSvg();
    }
    return this.#d3SvgMemo;
  }

  get #d3Group() {
    if (!this.#d3GroupMemo) {
      this.#d3GroupMemo = this.#createMainGroup();
    }

    return this.#d3GroupMemo;
  }

  get #d3Content() {
    if (!this.#d3ContentMemo) {
      this.#d3ContentMemo = this.#createContent();
    }
    return this.#d3ContentMemo;
  }

  #createMainSvg() {
    return this.#d3Container
      .append("svg")
      .attr("width", "100%")
      .attr("class", "relative aspect-1")
      .attr("viewBox", [0, 0, this.#d3ViewboxWidth, this.#d3ViewboxHeight]);
  }

  #createMainGroup() {
    return this.#d3Svg
      .append("g")
      .attr(
        "transform",
        `translate(${this.#d3ViewboxWidth / 2},${this.#d3ViewboxHeight / 2})`,
      );
  }

  #createContent() {
    this.#d3ContentMemo = this.#d3Container
      .append("div")
      .attr(
        "class",
        "absolute inset-0 w-full text-center flex flex-col items-center justify-center",
      );
    return this.#d3ContentMemo;
  }
}

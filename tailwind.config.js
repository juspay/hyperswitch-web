const plugin = require("tailwindcss/plugin");
const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  darkMode: "class",
  content: ["./src/**/*.js"],
  theme: {
    fontFamily: {
      "ibm-plex": '"IBM Plex Sans"',
      "ibm-plex-mono": '"IBM Plex Mono"',
      "fira-code": '"Fira Code"',
    },
    screens: {
      xs: "420px",
      ...defaultTheme.screens,
    },
    extend: {
      keyframes: {
        wiggle: {
          "0%, 100%": { transform: "rotate(-3deg)" },
          "50%": { transform: "rotate(3deg)" },
        },
        wobble: {
          "0%": { transform: "translateX(0%)" },
          "15%": {
            transform: "translateX(-10%) rotate(-5deg)",
          },
          "30%": { transform: "translateX(10%) rotate(3deg) " },
          "45%": {
            transform: "translateX(-8%) rotate(-3deg)",
          },
          "60%": { transform: "translateX(8%) rotate(2deg)" },
          "75%": {
            transform: "translateX(-5%) rotate(-1deg)",
          },
          "100%": { transform: "translateX(0%)" },
        },
        slideInFromLeft: {
          "0%": {
            transform: "translateX(100%)",
            opacity: "0",
          },
          "100%": {
            transform: "translateX(-0%)",
            opacity: "1",
          },
        },
        slideInFromRight: {
          "0%": {
            transform: "translateX(-200%)",
          },
          "100%": {
            transform: "translateX(0%)",
          },
        },
        shimmer: {
          "100%": { transform: "translateX(100%)" },
        },
        load: {
          "0%": { transform: "scale(1)" },
          "50%": { transform: "scale(0)", backgroundColor: "#1865ff" },
          "100%": { transform: "scale(1)" },
        },
        slowShow: {
          "0%": {
            opacity: "0",
          },
          "100%": {
            opacity: "1",
          },
        },
        zoomIn: {
          "0%": {
            opacity: "0",
            transform: "scale(1.1)",
          },
          "100%": {
            opacity: "1",
            transform: "scale(1)",
          },
        },
        zoomOut: {
          "0%": {
            opacity: "1",
            transform: "scale(1)",
          },
          "100%": {
            opacity: "0",
            transform: "scale(0.9)",
          },
        },
        slowFade: {
          "0%": {
            opacity: "1",
          },
          "100%": {
            opacity: "0",
          },
        },
      },
      fontSize: {
        body: "1rem",
        small: "0.85rem",
      },
      animation: {
        "spin-slow": "spin 3s linear infinite",
        wobble: "wobble 0.2s ease-in-out",
        slideLeft: "slideInFromLeft 0.2s ease-out 0s 1",
        slideRight: "slideInFromRight 0.3s ease-out 0s 1",
        load: "load 1.6s ease infinite",
        slowShow: "slowShow 0.4s ease-in",
        slowShowInf: "slowShow 1s ease-in infinite",
        slowFade: "slowFade 0.4s ease-out",
        zoomIn: "zoomIn 0.4s ease-in",
        zoomOut: "zoomOut 0.4s ease-out",
      },
      colors: {
        blue: {
          50: "#F2FAFF",
          100: "#E6F5FF",
          200: "#CCEBFF",
          300: "#B3E0FF",
          400: "#99D6FF",
          500: "#80CCFF",
          550: "#F5F7FC",
          600: "#66C2FF",
          650: "#0099ff",
          700: "#4DB8FF",
          750: "#0585DA",
          800: "#0099FF",
          850: "#0585DA",
          900: "#0B79C3",
          950: "#4581E5",
          table_green: "#CDEBEB",
          table_blue: "#CECFE1",
          table_yellow: "#F5DFB4",
          table_red: "#EDB0B0",
          table_gray: "#DDDDDD",
          table_orange: "#EDBE93",
          border: "#0099FF",
        },
        "status-green": "#36AF47",
        "status-blue": "#0585DD",
        "status-yellow": "#F7981C",
        "status-gray": "#5B5F62",
        "table-violet": "#3D5BF00F",
        "table-border": "#EBEEFE",
        "progress-bar-red": "#ef6969",
        "progress-bar-blue": "#72b4f9",
        "progress-bar-orange": "#f7981c",
        "progress-bar-green": "#36af47",
        "security-tab-light-gray": "#d6d6ce",
        "security-tab-dark-gray": "#39373b",
        "jp-gray": {
          50: "#FAFBFD",
          100: "#F7F8FA",
          200: "#F1F5FA",
          250: "#FDFEFF",
          300: "#E7EAF1",
          350: "#F1F5FA",
          400: "#D1D4D8",
          450: "#FDFEFF",
          500: "#D8DDE9",
          600: "#CCCFD4",
          700: "#9A9FA8",
          800: "#67707D",
          850: "#31333A",
          900: "#354052",
          950: "#202124",
          960: "#2C2D2F",
          970: "#1B1B1D",
          920: "#282A2F",
          930: "#989AA5",
          940: "#CCD2E2",
          980: "#ACADB8",
          disabled_border: "#262626",
          table_hover: "#F9FBFF",
          darkgray_background: "#0F1011",
          lightgray_background: "#191A1A",
          text_darktheme: "#F6F8F9",
          lightmode_steelgray: "#CCD2E2",
          tooltip_bg_dark: "#F7F7FA",
          tooltip_bg_light: "#23211D",
          disable_heading_color: "#ACADB8",
          dark_disable_border_color: "#8d8f9a",
          light_table_border_color: "#CDD4EB",
          dark_background_hover: "#F8FAFC",
          no_data_border: "#6E727A",
          border_gray: "#354052",
          conflicts_light: "#f5f7fc",
        },
        "infra-gray": {
          300: "#CCCCCC",
          700: "#3F3447",
          800: "#28212D",
          900: "#1A141F",
        },
        "infra-indigo": {
          50: "#E4E8FC10",
          100: "#E4E8FC15",
          200: "#E4E8FC47",
          300: "#E4E8FC64",
          400: "#E4E8FC87",
          500: "#E4E8FC",
          800: "#758AF0",
        },
        "infra-red": {
          600: "#FAABA6",
          900: "#F97F77",
        },
        "infra-amber": {
          600: "#F8D2A2",
          900: "#F9C077",
        },
        brown: {
          600: "#77612a",
        },
        green: {
          50: "#F3FBF4",
          100: "#E7F7E9",
          200: "#CFEFD3",
          300: "#B7E7BE",
          400: "#9FDFA8",
          500: "#86D792",
          600: "#6ED07C",
          700: "#56C866",
          800: "#0EB025",
          850: "#008236",
          900: "#20792C",
          950: "#36AF47",
        },
        red: {
          50: "#fef2f2",
          950: "#F04849",
          960: "#EF6969",
          970: "#FF0000",
        },
        orange: {
          600: "#ffb03b",
          950: "#F7981C",
          960: "#E89519",
        },
      },
      fontSize: {
        "fs-10": "10px",
        "fs-11": "11px",
        "fs-13": "13px",
        "fs-14": "14px",
        "fs-16": "16px",
        "fs-18": "18px",
        "fs-20": "20px",
        "fs-24": "24px",
      },
      opacity: {
        3: "0.03",
      },
      borderWidth: {
        3: "3px",
      },
      boxShadow: {
        generic_shadow: "0 2px 5px 0 rgba(0, 0, 0, 0.12)",
        generic_shadow_dark: "0px 2px 5px 0 rgba(0, 0, 0, 0.78)",
        side_shadow: "0 4px 4px rgba(0, 0, 0, 0.25)",
      },
      margin: {
        "20vh": "20vh",
      },
      width: {
        "1/10": "10%",
        "2/10": "20%",
        "3/10": "30%",
        "4/10": "40%",
        "5/10": "50%",
        "6/10": "60%",
        "7/10": "70%",
        "8/10": "80%",
        "9/10": "90%",
      },
      height: {
        "min-content": "min-content",
      },
    },
  },
  variants: {},
  plugins: [
    plugin(function ({ addUtilities }) {
      const newUtilities = {
        ".no-scrollbar::-webkit-scrollbar": {
          display: "none",
        },
        "*": {
          scrollbarWidth: "none", // firefox
        },
        ".show-scrollbar::-webkit-scrollbar": {
          overflow: "scroll",
          height: "4px",
          width: "4px",
        },
        ".show-scrollbar::-webkit-scrollbar-thumb": {
          borderRadius: "2px",
          backgroundColor: "#9A9FA8",
        },
      };
      addUtilities(newUtilities);
    }),
  ],
};
